import copy
import json
import time
from django.db import connection
from django.db.models import Prefetch, Q
from rest_framework import status, permissions, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from .models import ConnectSession, ConnectParticipant
from .serializers import ConnectSessionSerializer, ConnectJoinSerializer
from playlists.models import Playlist

_PLAYBACK_COL_READY = False
# Cache mémoire ultra-rapide des salons actifs pour éviter les lectures/écritures SQL Supabase
# à chaque tick de 1,2s (réduit l'Egress Supabase de >98% tout en gardant une latence <50ms).
_SESSION_RAM_CACHE = {}


def _ensure_playback_state_column():
    """Auto-ajoute la colonne playback_state sur connect_connectsession (PostgreSQL Vercel & SQLite local)."""
    global _PLAYBACK_COL_READY
    if _PLAYBACK_COL_READY:
        return True
    try:
        with connection.cursor() as cursor:
            vendor = connection.vendor
            if vendor == 'postgresql':
                cursor.execute(
                    "ALTER TABLE connect_connectsession "
                    "ADD COLUMN IF NOT EXISTS playback_state TEXT DEFAULT '{}'"
                )
            else:
                cursor.execute("PRAGMA table_info(connect_connectsession)")
                cols = [row[1] for row in cursor.fetchall()]
                if 'playback_state' not in cols:
                    cursor.execute(
                        "ALTER TABLE connect_connectsession "
                        "ADD COLUMN playback_state TEXT DEFAULT '{}'"
                    )
        _PLAYBACK_COL_READY = True
        return True
    except Exception:
        return False


def _read_session_state(session_id: int, allow_ram: bool = True) -> dict:
    now = time.time()
    if allow_ram:
        cached = _SESSION_RAM_CACHE.get(session_id)
        if cached and (now - cached.get('read_at', 0.0) < 6.0):
            return cached['state']
    if not _ensure_playback_state_column():
        return {}
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT playback_state FROM connect_connectsession WHERE id = %s",
                [session_id],
            )
            row = cursor.fetchone()
            if row and row[0]:
                raw = row[0]
                parsed = None
                if isinstance(raw, dict):
                    parsed = raw
                elif isinstance(raw, str) and raw.strip():
                    loaded = json.loads(raw)
                    if isinstance(loaded, dict):
                        parsed = loaded
                if parsed is not None:
                    entry = _SESSION_RAM_CACHE.setdefault(session_id, {})
                    entry['state'] = parsed
                    entry['read_at'] = now
                    return parsed
    except Exception:
        pass
    return {}


def _write_session_state(session_id: int, state_dict: dict, force_db: bool = True) -> None:
    now = time.time()
    entry = _SESSION_RAM_CACHE.setdefault(session_id, {})
    entry['state'] = state_dict
    entry['read_at'] = now
    last_db_write = entry.get('db_written_at', 0.0)
    if not force_db and (now - last_db_write < 8.0):
        return
    if not _ensure_playback_state_column():
        return
    try:
        payload = json.dumps(state_dict, ensure_ascii=False)
        with connection.cursor() as cursor:
            cursor.execute(
                "UPDATE connect_connectsession SET playback_state = %s WHERE id = %s",
                [payload, session_id],
            )
        entry['db_written_at'] = now
    except Exception:
        pass


def _sanitize_avatar(raw_avatar) -> str:
    if not isinstance(raw_avatar, str):
        return ''
    cleaned = raw_avatar.strip()
    if not cleaned:
        return ''
    if cleaned.startswith(('https://', 'http://')) and len(cleaned) <= 600:
        return cleaned
    # Miniature Base64 compacte (max 32 Ko pour préserver l'Egress Supabase)
    if cleaned.startswith('data:image/') and len(cleaned) <= 32000:
        return cleaned
    return ''


def _sanitize_track(value):
    if not isinstance(value, dict):
        return None
    track_id = str(value.get('id') or '').strip()
    title = str(value.get('title') or '').strip()
    artist_name = str(value.get('artist_name') or value.get('artistName') or '').strip()
    if not track_id or not title or not artist_name:
        return None
    try:
        duration = int(value.get('duration_seconds') or value.get('durationSeconds') or 0)
    except (TypeError, ValueError):
        duration = 0
    cover_url = str(value.get('cover_url') or value.get('coverUrl') or '').strip()
    if not cover_url.startswith(('https://', 'http://')) or len(cover_url) > 500:
        cover_url = ''
    album_name = str(value.get('album_name') or value.get('albumName') or '')[:255]
    genre = str(value.get('genre') or '')[:100]
    yt_vid = str(value.get('youtube_video_id') or '').strip()[:16]
    result = {
        'id': track_id[:64],
        'title': title[:255],
        'artist_name': artist_name[:255],
        'album_name': album_name,
        'cover_url': cover_url,
        'duration_seconds': max(0, min(duration, 86400)),
        'audio_url': '',
        'genre': genre,
        'license_ccurl': '',
    }
    if yt_vid:
        result['youtube_video_id'] = yt_vid
    return result


def _sanitize_track_list(raw_list, max_items: int = 35) -> list:
    if not isinstance(raw_list, list):
        return []
    cleaned = []
    seen = set()
    for item in raw_list:
        t = _sanitize_track(item)
        if t is not None and t['id'] not in seen:
            seen.add(t['id'])
            cleaned.append(t)
            if len(cleaned) >= max_items:
                break
    return cleaned


def _sort_suggestion_threads(threads: list, avatars: dict) -> list:
    """Trie les threads de suggestions multi-participants par ordre de priorité :
    1) Nombre de votes/soutiens décroissant (-votes_count),
    2) Équité Round-Robin entre participants (la 1re suggestion de chaque invité passe avant la 2e/3e d'un même invité),
    3) Ordre chronologique d'arrivée (created_ts FIFO).
    """
    if not isinstance(threads, list):
        return []
    valid = [dict(t) for t in threads if isinstance(t, dict) and t.get('id')]
    valid.sort(key=lambda x: float(x.get('created_ts', 0.0)))

    per_user_slot = {}
    for t in valid:
        uid = str(t.get('user_id') or t.get('username') or '')
        slot = per_user_slot.get(uid, 0)
        t['priority_slot'] = slot
        per_user_slot[uid] = slot + 1
        voter_ids = t.get('voter_ids') if isinstance(t.get('voter_ids'), list) else []
        t['votes_count'] = max(1, len(voter_ids))
        if uid in avatars and not t.get('user_avatar'):
            t['user_avatar'] = avatars[uid]

    valid.sort(
        key=lambda x: (
            -int(x.get('votes_count', 1)),
            int(x.get('priority_slot', 0)),
            float(x.get('created_ts', 0.0)),
        )
    )
    for idx, t in enumerate(valid):
        t['priority_rank'] = idx + 1
    return valid


def _get_cached_serialized_session(session: ConnectSession, force_refresh: bool = False) -> dict:
    now = time.time()
    entry = _SESSION_RAM_CACHE.setdefault(session.pk, {})
    cached_data = entry.get('serialized_session')
    if not force_refresh and cached_data and (now - entry.get('serialized_at', 0.0) < 6.0):
        return copy.deepcopy(cached_data)

    # Chargement optimisé en 2 requêtes légères SANS jamais lire favorite_artists / superliked_tracks / favorite_albums
    light_participants_qs = (
        ConnectParticipant.objects.select_related('user')
        .defer(
            'user__password',
            'user__favorite_artists',
            'user__superliked_tracks',
            'user__favorite_albums',
        )
    )
    light_session = (
        ConnectSession.objects.select_related('host_user', 'playlist')
        .defer(
            'host_user__password',
            'host_user__favorite_artists',
            'host_user__superliked_tracks',
            'host_user__favorite_albums',
        )
        .prefetch_related(Prefetch('participants', queryset=light_participants_qs))
        .filter(pk=session.pk)
        .first()
    ) or session

    fresh = dict(ConnectSessionSerializer(light_session).data)
    entry['serialized_session'] = fresh
    entry['serialized_at'] = now
    return copy.deepcopy(fresh)


def _enrich_session_response(
    session: ConnectSession,
    state_dict: dict,
    client_meta_rev: int = -1,
    force_participants_refresh: bool = False,
) -> dict:
    server_meta_rev = int(state_dict.get('meta_rev', 1))
    now = time.time()

    # Si le client possède déjà exactement la même révision de métadonnées (avatars, file, threads, participants),
    # on renvoie un paquet delta ultra-léger (< 500 octets au lieu de 300 Ko !).
    if client_meta_rev > 0 and client_meta_rev == server_meta_rev and not force_participants_refresh:
        return {
            'id': session.pk,
            'status': session.status,
            'delta': True,
            'max_participants': 20,
            'server_now': now,
            'playback_state': {
                'seq': int(state_dict.get('seq', 0)),
                'meta_rev': server_meta_rev,
                'track': state_dict.get('track'),
                'position': state_dict.get('position', 0.0),
                'is_playing': bool(state_dict.get('is_playing', False)),
                'is_buffering': bool(state_dict.get('is_buffering', False)),
                'server_timestamp': state_dict.get('server_timestamp', now),
                'reactions': state_dict.get('reactions', []),
            },
        }

    data = _get_cached_serialized_session(session, force_refresh=force_participants_refresh)
    avatars = state_dict.get('avatars') if isinstance(state_dict.get('avatars'), dict) else {}
    participants = data.get('participants')
    if isinstance(participants, list):
        for p in participants:
            if not isinstance(p, dict):
                continue
            u = p.get('user')
            uid = str(u.get('id')) if isinstance(u, dict) and u.get('id') is not None else str(p.get('id') or '')
            avatar = avatars.get(uid, '')
            p['avatar'] = avatar
            p['is_host'] = (uid == str(session.host_user_id))
            if isinstance(u, dict):
                u['avatar'] = avatar

    raw_threads = state_dict.get('suggestion_threads')
    if not isinstance(raw_threads, list):
        raw_threads = state_dict.get('suggestions', [])
    sorted_threads = _sort_suggestion_threads(raw_threads, avatars)

    data['delta'] = False
    data['playback_state'] = {
        'seq': int(state_dict.get('seq', 0)),
        'meta_rev': server_meta_rev,
        'track': state_dict.get('track'),
        'position': state_dict.get('position', 0.0),
        'is_playing': bool(state_dict.get('is_playing', False)),
        'is_buffering': bool(state_dict.get('is_buffering', False)),
        'server_timestamp': state_dict.get('server_timestamp', now),
        'shared_playlist_title': str(state_dict.get('shared_playlist_title') or 'File du salon'),
        'shared_queue': state_dict.get('shared_queue', []),
        'reactions': state_dict.get('reactions', []),
        'suggestion_threads': sorted_threads,
        'suggestions': sorted_threads,
    }
    data['max_participants'] = 20
    data['server_now'] = now
    return data

class ConnectSessionCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        playlist_id = request.data.get('playlist_id')

        if playlist_id:
            try:
                playlist = Playlist.objects.get(pk=playlist_id, user=request.user)
            except Playlist.DoesNotExist:
                return Response(
                    {"error": {"code": "FORBIDDEN", "message": "Cette playlist ne vous appartient pas ou est introuvable."}},
                    status=status.HTTP_403_FORBIDDEN
                )
        else:
            playlist = None

        session = ConnectSession.objects.create(
            host_user=request.user,
            status='active',
            playlist=playlist
        )

        ConnectParticipant.objects.create(
            session=session,
            user=request.user
        )

        state_dict = {
            'seq': 1,
            'meta_rev': 1,
            'avatars': {},
            'reactions': [],
            'suggestion_threads': [],
            'shared_playlist_title': str(request.data.get('shared_playlist_title') or 'File du salon')[:120],
            'shared_queue': _sanitize_track_list(request.data.get('shared_queue'), max_items=35),
        }
        avatar = _sanitize_avatar(request.data.get('avatar'))
        if avatar:
            state_dict['avatars'][str(request.user.id)] = avatar
        initial_track = _sanitize_track(request.data.get('track'))
        if initial_track:
            state_dict['track'] = initial_track
            state_dict['position'] = float(request.data.get('position') or 0.0)
            state_dict['is_playing'] = bool(request.data.get('is_playing', False))
            state_dict['is_buffering'] = bool(request.data.get('is_buffering', False))
            state_dict['server_timestamp'] = time.time()
            if not state_dict['shared_queue']:
                state_dict['shared_queue'] = [initial_track]
        _write_session_state(session.pk, state_dict, force_db=True)

        return Response(
            _enrich_session_response(session, state_dict, force_participants_refresh=True),
            status=status.HTTP_201_CREATED,
        )

class ConnectSessionJoinView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = ConnectJoinSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)

        invite_code = serializer.validated_data['invite_code'].upper().strip()

        try:
            session = ConnectSession.objects.get(invite_code=invite_code)
        except ConnectSession.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Code d'invitation invalide."}},
                status=status.HTTP_404_NOT_FOUND
            )

        if session.status == 'ended':
            return Response(
                {"error": {"code": "BAD_REQUEST", "message": "Cette session est terminée."}},
                status=status.HTTP_400_BAD_REQUEST
            )

        ConnectParticipant.objects.get_or_create(
            session=session,
            user=request.user
        )

        state_dict = _read_session_state(session.pk, allow_ram=False)
        avatar = _sanitize_avatar(request.data.get('avatar'))
        if avatar:
            avatars = state_dict.get('avatars') if isinstance(state_dict.get('avatars'), dict) else {}
            avatars[str(request.user.id)] = avatar
            state_dict['avatars'] = avatars
        state_dict['meta_rev'] = int(state_dict.get('meta_rev', 1)) + 1
        _write_session_state(session.pk, state_dict, force_db=True)

        return Response(
            _enrich_session_response(session, state_dict, force_participants_refresh=True),
            status=status.HTTP_200_OK,
        )

class ConnectSessionDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        try:
            # Enforce that only host or active participant can view the session
            session = ConnectSession.objects.filter(
                Q(host_user=request.user) | Q(participants__user=request.user),
                pk=pk
            ).distinct().get()
            state_dict = _read_session_state(session.pk)
            return Response(_enrich_session_response(session, state_dict), status=status.HTTP_200_OK)
        except ConnectSession.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Session introuvable ou accès refusé."}},
                status=status.HTTP_404_NOT_FOUND
            )


class ConnectSessionSyncView(APIView):
    """Synchronisation HTTP temps réel compatible 100 % Vercel Serverless."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            session = ConnectSession.objects.filter(
                Q(host_user=request.user) | Q(participants__user=request.user),
                pk=pk
            ).distinct().get()
        except ConnectSession.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Session introuvable ou terminée."}},
                status=status.HTTP_404_NOT_FOUND
            )

        if session.status == 'ended':
            return Response(
                {"status": "ended", "event": "session_ended"},
                status=status.HTTP_200_OK,
            )

        state_dict = _read_session_state(session.pk)
        changed = False
        meta_changed = False
        now = time.time()

        # 1. Mise à jour de la photo de profil du participant
        avatar = _sanitize_avatar(request.data.get('avatar'))
        if avatar:
            avatars = state_dict.get('avatars') if isinstance(state_dict.get('avatars'), dict) else {}
            uid = str(request.user.id)
            if avatars.get(uid) != avatar:
                avatars[uid] = avatar
                state_dict['avatars'] = avatars
                changed = True
                meta_changed = True

        # 2. Si c'est l'hôte, mise à jour de l'état de lecture (avec numéro de séquence monotone `seq`)
        if session.host_user_id == request.user.id:
            incoming_seq = request.data.get('seq')
            current_seq = int(state_dict.get('seq', 0))
            is_stale_host_packet = False
            if incoming_seq is not None:
                try:
                    incoming_seq_int = int(incoming_seq)
                    if incoming_seq_int < current_seq:
                        is_stale_host_packet = True
                    elif incoming_seq_int > current_seq:
                        state_dict['seq'] = incoming_seq_int
                        meta_changed = True
                except (TypeError, ValueError):
                    pass

            if not is_stale_host_packet:
                if 'position' in request.data or 'is_playing' in request.data or 'track' in request.data:
                    pos = request.data.get('position', state_dict.get('position', 0.0))
                    try:
                        pos = max(0.0, float(pos))
                    except (TypeError, ValueError):
                        pos = 0.0
                    state_dict['position'] = pos
                    if 'is_playing' in request.data:
                        new_playing = bool(request.data.get('is_playing'))
                        if state_dict.get('is_playing') != new_playing:
                            meta_changed = True
                        state_dict['is_playing'] = new_playing
                    if 'is_buffering' in request.data:
                        new_buf = bool(request.data.get('is_buffering'))
                        if state_dict.get('is_buffering') != new_buf:
                            meta_changed = True
                        state_dict['is_buffering'] = new_buf
                    state_dict['server_timestamp'] = now
                    track = _sanitize_track(request.data.get('track'))
                    if track is not None:
                        prev_track_id = (state_dict.get('track') or {}).get('id') if isinstance(state_dict.get('track'), dict) else None
                        if prev_track_id != track['id']:
                            meta_changed = True
                        state_dict['track'] = track
                        if session.current_jamendo_track_id != track['id']:
                            session.current_jamendo_track_id = track['id']
                            session.save(update_fields=['current_jamendo_track_id'])
                    changed = True

                if 'shared_playlist_title' in request.data:
                    new_title = str(
                        request.data.get('shared_playlist_title') or 'File du salon'
                    )[:120]
                    if state_dict.get('shared_playlist_title') != new_title:
                        state_dict['shared_playlist_title'] = new_title
                        changed = True
                        meta_changed = True

                if 'shared_queue' in request.data:
                    new_queue = _sanitize_track_list(
                        request.data.get('shared_queue'),
                        max_items=35,
                    )
                    state_dict['shared_queue'] = new_queue
                    changed = True
                    meta_changed = True

            clear_suggestion_id = request.data.get('clear_suggestion_id')
            if isinstance(clear_suggestion_id, str) and clear_suggestion_id.strip():
                target_sid = clear_suggestion_id.strip()
                threads = state_dict.get('suggestion_threads')
                if not isinstance(threads, list):
                    threads = state_dict.get('suggestions', [])
                state_dict['suggestion_threads'] = [
                    s for s in threads
                    if isinstance(s, dict) and str(s.get('id')) != target_sid
                ]
                state_dict.pop('suggestions', None)
                changed = True
                meta_changed = True

        # 3. Réaction en direct (hôte ou invité)
        reaction = request.data.get('reaction')
        if isinstance(reaction, str) and reaction.strip():
            emoji = reaction.strip()[:8]
            reactions = state_dict.get('reactions') if isinstance(state_dict.get('reactions'), list) else []
            reactions = [r for r in reactions if isinstance(r, dict) and now - float(r.get('ts', 0)) < 25.0]
            reactions.append({
                'id': f"{int(now * 1000)}_{request.user.id}",
                'emoji': emoji,
                'username': request.user.username,
                'user_id': request.user.id,
                'ts': now,
            })
            state_dict['reactions'] = reactions[-12:]
            changed = True

        # 4. Vote / Soutien (+1) sur un thread de suggestion existant
        upvote_id = request.data.get('upvote_suggestion_id')
        if isinstance(upvote_id, str) and upvote_id.strip():
            threads = state_dict.get('suggestion_threads')
            if not isinstance(threads, list):
                threads = state_dict.get('suggestions', [])
            for t in threads:
                if isinstance(t, dict) and str(t.get('id')) == upvote_id.strip():
                    voter_ids = t.get('voter_ids') if isinstance(t.get('voter_ids'), list) else []
                    if request.user.id not in voter_ids:
                        voter_ids.append(request.user.id)
                        t['voter_ids'] = voter_ids
                        changed = True
                        meta_changed = True
                    break
            state_dict['suggestion_threads'] = threads

        # 5. Création d'un thread de suggestion (Son, Album ou Playlist) par un participant
        suggestion_payload = request.data.get('suggestion_payload')
        legacy_track = _sanitize_track(request.data.get('suggested_track'))
        if not isinstance(suggestion_payload, dict) and legacy_track is not None:
            suggestion_payload = {
                'kind': 'track',
                'title': legacy_track['title'],
                'subtitle': legacy_track['artist_name'],
                'cover_url': legacy_track['cover_url'],
                'tracks': [legacy_track],
            }

        if isinstance(suggestion_payload, dict):
            kind = str(suggestion_payload.get('kind') or 'track').strip().lower()
            if kind not in ('track', 'album', 'playlist'):
                kind = 'track'
            tracks = _sanitize_track_list(suggestion_payload.get('tracks'), max_items=30)
            if tracks:
                title = str(suggestion_payload.get('title') or tracks[0]['title']).strip()[:180]
                subtitle = str(
                    suggestion_payload.get('subtitle')
                    or (tracks[0]['artist_name'] if kind == 'track' else f"{len(tracks)} titres")
                ).strip()[:180]
                cover_url = str(suggestion_payload.get('cover_url') or tracks[0].get('cover_url') or '').strip()[:500]
                uname = request.user.username or 'Un participant'
                if kind == 'album':
                    action_label = f"{uname} a suggéré cet album"
                elif kind == 'playlist':
                    action_label = f"{uname} a suggéré cette playlist"
                else:
                    action_label = f"{uname} a suggéré ce son"

                threads = state_dict.get('suggestion_threads')
                if not isinstance(threads, list):
                    threads = state_dict.get('suggestions', [])

                dedup_key = f"{kind}:{title.lower()}:{tracks[0]['id']}"
                existing = next(
                    (t for t in threads if isinstance(t, dict) and t.get('dedup_key') == dedup_key),
                    None,
                )
                if existing is not None:
                    voter_ids = existing.get('voter_ids') if isinstance(existing.get('voter_ids'), list) else []
                    if request.user.id not in voter_ids:
                        voter_ids.append(request.user.id)
                        existing['voter_ids'] = voter_ids
                        changed = True
                        meta_changed = True
                else:
                    avatars = state_dict.get('avatars') if isinstance(state_dict.get('avatars'), dict) else {}
                    threads.append({
                        'id': f"sug_{int(now * 1000)}_{request.user.id}",
                        'dedup_key': dedup_key,
                        'kind': kind,
                        'title': title,
                        'subtitle': subtitle,
                        'cover_url': cover_url,
                        'tracks': tracks,
                        'label': action_label,
                        'username': uname,
                        'user_id': request.user.id,
                        'user_avatar': avatars.get(str(request.user.id), ''),
                        'voter_ids': [request.user.id],
                        'votes_count': 1,
                        'created_ts': now,
                    })
                    state_dict['suggestion_threads'] = threads[-24:]
                    state_dict.pop('suggestions', None)
                    changed = True
                    meta_changed = True

        if meta_changed:
            state_dict['meta_rev'] = int(state_dict.get('meta_rev', 1)) + 1

        if changed:
            _write_session_state(
                session.pk,
                state_dict,
                force_db=bool(meta_changed or reaction),
            )

        try:
            client_meta_rev = int(request.data.get('known_meta_rev') or -1)
        except (TypeError, ValueError):
            client_meta_rev = -1

        return Response(
            _enrich_session_response(
                session,
                state_dict,
                client_meta_rev=client_meta_rev if not meta_changed else -1,
            ),
            status=status.HTTP_200_OK,
        )

class ConnectSessionLeaveView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            # Must verify participation to avoid enumeration
            session = ConnectSession.objects.filter(
                Q(host_user=request.user) | Q(participants__user=request.user),
                pk=pk
            ).distinct().get()
        except ConnectSession.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Session introuvable ou vous n'y participez pas."}},
                status=status.HTTP_404_NOT_FOUND
            )

        ConnectParticipant.objects.filter(session=session, user=request.user).delete()
        _SESSION_RAM_CACHE.pop(session.pk, None)

        # If host leaves or no participants left, close the session and purge heavy playback_state blob
        if session.host_user_id == request.user.id or session.participants.count() == 0:
            session.status = 'ended'
            session.save(update_fields=['status'])
            _write_session_state(session.pk, {}, force_db=True)
            _SESSION_RAM_CACHE.pop(session.pk, None)
            channel_layer = get_channel_layer()
            if channel_layer is not None:
                try:
                    async_to_sync(channel_layer.group_send)(
                        f'connect_{session.pk}',
                        {'type': 'connect_event', 'event': 'session_ended'},
                    )
                except Exception:
                    # Leaving the session must still succeed if Redis is unavailable.
                    pass

        return Response({"message": "Vous avez quitté la session."}, status=status.HTTP_200_OK)
