import json
import time
from django.db import connection
from django.db.models import Q
from rest_framework import status, permissions, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from .models import ConnectSession, ConnectParticipant
from .serializers import ConnectSessionSerializer, ConnectJoinSerializer
from playlists.models import Playlist

_PLAYBACK_COL_READY = False


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


def _read_session_state(session_id: int) -> dict:
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
                if isinstance(raw, dict):
                    return raw
                if isinstance(raw, str) and raw.strip():
                    parsed = json.loads(raw)
                    if isinstance(parsed, dict):
                        return parsed
    except Exception:
        pass
    return {}


def _write_session_state(session_id: int, state_dict: dict) -> None:
    if not _ensure_playback_state_column():
        return
    try:
        payload = json.dumps(state_dict, ensure_ascii=False)
        with connection.cursor() as cursor:
            cursor.execute(
                "UPDATE connect_connectsession SET playback_state = %s WHERE id = %s",
                [payload, session_id],
            )
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
    if cleaned.startswith('data:image/') and len(cleaned) <= 160000:
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
    return {
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


def _enrich_session_response(session: ConnectSession, state_dict: dict) -> dict:
    data = dict(ConnectSessionSerializer(session).data)
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
    data['playback_state'] = {
        'track': state_dict.get('track'),
        'position': state_dict.get('position', 0.0),
        'is_playing': bool(state_dict.get('is_playing', False)),
        'server_timestamp': state_dict.get('server_timestamp', time.time()),
        'reactions': state_dict.get('reactions', []),
        'suggestions': state_dict.get('suggestions', []),
    }
    data['server_now'] = time.time()
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

        state_dict = {'avatars': {}, 'reactions': [], 'suggestions': []}
        avatar = _sanitize_avatar(request.data.get('avatar'))
        if avatar:
            state_dict['avatars'][str(request.user.id)] = avatar
        initial_track = _sanitize_track(request.data.get('track'))
        if initial_track:
            state_dict['track'] = initial_track
            state_dict['position'] = float(request.data.get('position') or 0.0)
            state_dict['is_playing'] = bool(request.data.get('is_playing', False))
            state_dict['server_timestamp'] = time.time()
        _write_session_state(session.pk, state_dict)

        return Response(_enrich_session_response(session, state_dict), status=status.HTTP_201_CREATED)

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

        state_dict = _read_session_state(session.pk)
        avatar = _sanitize_avatar(request.data.get('avatar'))
        if avatar:
            avatars = state_dict.get('avatars') if isinstance(state_dict.get('avatars'), dict) else {}
            avatars[str(request.user.id)] = avatar
            state_dict['avatars'] = avatars
            _write_session_state(session.pk, state_dict)

        return Response(_enrich_session_response(session, state_dict), status=status.HTTP_200_OK)

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

        # 2. Si c'est l'hôte, mise à jour de l'état de lecture
        if session.host_user_id == request.user.id:
            if 'position' in request.data or 'is_playing' in request.data or 'track' in request.data:
                pos = request.data.get('position', state_dict.get('position', 0.0))
                try:
                    pos = max(0.0, float(pos))
                except (TypeError, ValueError):
                    pos = 0.0
                state_dict['position'] = pos
                if 'is_playing' in request.data:
                    state_dict['is_playing'] = bool(request.data.get('is_playing'))
                state_dict['server_timestamp'] = now
                track = _sanitize_track(request.data.get('track'))
                if track is not None:
                    state_dict['track'] = track
                    if session.current_jamendo_track_id != track['id']:
                        session.current_jamendo_track_id = track['id']
                        session.save(update_fields=['current_jamendo_track_id'])
                changed = True

            clear_suggestion_id = request.data.get('clear_suggestion_id')
            if isinstance(clear_suggestion_id, str) and clear_suggestion_id.strip():
                suggestions = state_dict.get('suggestions') if isinstance(state_dict.get('suggestions'), list) else []
                state_dict['suggestions'] = [
                    s for s in suggestions
                    if isinstance(s, dict) and s.get('id') != clear_suggestion_id.strip()
                ]
                changed = True

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

        # 4. Suggestion de son par un participant
        suggested_track = _sanitize_track(request.data.get('suggested_track'))
        if suggested_track is not None:
            suggestions = state_dict.get('suggestions') if isinstance(state_dict.get('suggestions'), list) else []
            if not any(isinstance(s, dict) and s.get('id') == suggested_track['id'] for s in suggestions):
                suggested_entry = dict(suggested_track)
                suggested_entry['suggested_by'] = request.user.username
                suggestions.append(suggested_entry)
                state_dict['suggestions'] = suggestions[-10:]
                changed = True

        if changed:
            _write_session_state(session.pk, state_dict)

        return Response(_enrich_session_response(session, state_dict), status=status.HTTP_200_OK)

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

        # If host leaves or no participants left, close the session
        if session.host_user == request.user or session.participants.count() == 0:
            session.status = 'ended'
            session.save()
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
