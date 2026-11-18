import hashlib
import json
import re
import urllib.parse
import urllib.request
from django.http import StreamingHttpResponse
from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from django.core.cache import cache
from .services.yt_client import YTClient
from .models import TrackCache
from .serializers import TrackSerializer, GenreSerializer

def _pagination_params(request):
    """Parse and bound pagination values before passing them to the provider."""
    try:
        limit = int(request.query_params.get('limit', 20))
        offset = int(request.query_params.get('offset', 0))
    except (TypeError, ValueError):
        return None, None, Response(
            {'error': {'code': 'INVALID_PAGINATION', 'message': 'limit et offset doivent être des nombres entiers.'}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if limit < 1 or offset < 0:
        return None, None, Response(
            {'error': {'code': 'INVALID_PAGINATION', 'message': 'limit doit être positif et offset ne peut pas être négatif.'}},
            status=status.HTTP_400_BAD_REQUEST,
        )
    return min(limit, 50), offset, None


def _paginated_response(request, tracks, limit, offset):
    """Wrap provider-paginated results without slicing the current page twice."""
    params = request.query_params.copy()
    next_url = None
    previous_url = None
    if len(tracks) == limit:
        params['offset'] = str(offset + limit)
        next_url = request.build_absolute_uri(request.path) + '?' + params.urlencode()
    if offset > 0:
        params['offset'] = str(max(0, offset - limit))
        previous_url = request.build_absolute_uri(request.path) + '?' + params.urlencode()

    return Response({
        'count': offset + len(tracks),
        'next': next_url,
        'previous': previous_url,
        'results': TrackSerializer(tracks, many=True).data,
    }, status=status.HTTP_200_OK)

def cache_or_update_tracks(tracks_data):
    """Helper utility to persist tracks into database TrackCache for offline/instant lookup."""
    for track in tracks_data:
        if not track.get('youtube_id'):
            continue
        defaults = {
            'title': track.get('title', ''),
            'artist_name': track.get('artist_name', ''),
            'album_name': track.get('album_name', ''),
            'cover_url': track.get('cover_url', ''),
            'duration_seconds': int(track.get('duration_seconds', 0)),
            'genre': track.get('genre', ''),
            'license_ccurl': track.get('license_ccurl', ''),
        }
        audio_url = str(track.get('audio_url') or '').strip()
        if audio_url:
            defaults['audio_url'] = audio_url
        TrackCache.objects.update_or_create(
            youtube_id=str(track['youtube_id']),
            defaults=defaults,
        )

class TrendingTracksView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        limit, offset, error = _pagination_params(request)
        if error:
            return error

        cache_key = f"trending_tracks_{limit}_{offset}"
        cached_data = cache.get(cache_key)

        if cached_data is not None:
            return Response(cached_data, status=status.HTTP_200_OK)

        client = YTClient()
        tracks = client.get_trending_tracks(limit=limit, offset=offset)
        cache_or_update_tracks(tracks)

        response_data = _paginated_response(request, tracks, limit, offset).data

        # Cache response for 1 hour (3600s) to strictly conserve Jamendo API quota
        cache.set(cache_key, response_data, 3600)
        return Response(response_data, status=status.HTTP_200_OK)

class SearchTracksView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        query = request.query_params.get('q', '').strip()
        genre = request.query_params.get('genre', '').strip()
        limit, offset, error = _pagination_params(request)
        if error:
            return error

        cache_key = f"search_tracks_{query}_{genre}_{limit}_{offset}"
        cached_data = cache.get(cache_key)

        if cached_data is not None:
            return Response(cached_data, status=status.HTTP_200_OK)

        client = YTClient()
        tracks = client.search_tracks(query=query, limit=limit, offset=offset, genre=genre)
        cache_or_update_tracks(tracks)

        response_data = _paginated_response(request, tracks, limit, offset).data

        # Cache search results for 15 minutes (900s)
        cache.set(cache_key, response_data, 900)
        return Response(response_data, status=status.HTTP_200_OK)

class TrackDetailView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, track_id):
        # 1. Check local database TrackCache first
        try:
            cached_track = TrackCache.objects.get(youtube_id=str(track_id))
            serializer = TrackSerializer({
                "youtube_id": cached_track.youtube_id,
                "title": cached_track.title,
                "artist_name": cached_track.artist_name,
                "album_name": cached_track.album_name,
                "cover_url": cached_track.cover_url,
                "duration_seconds": cached_track.duration_seconds,
                "audio_url": cached_track.audio_url,
                "genre": cached_track.genre,
                "license_ccurl": cached_track.license_ccurl,
            })
            return Response(serializer.data, status=status.HTTP_200_OK)
        except TrackCache.DoesNotExist:
            pass

        # 2. Query YT Client in fallback
        client = YTClient()
        track = client.get_track_detail(str(track_id))

        if not track:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Morceau introuvable."}},
                status=status.HTTP_404_NOT_FOUND
            )

        cache_or_update_tracks([track])
        return Response(TrackSerializer(track).data, status=status.HTTP_200_OK)

class TrackLyricsView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, track_id):
        client = YTClient()
        lyrics = client.get_lyrics(str(track_id))
        
        if lyrics:
            return Response({"lyrics": lyrics}, status=status.HTTP_200_OK)
            
        return Response({"lyrics": None}, status=status.HTTP_200_OK)

class GenresView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        cache_key = "genres_list"
        cached_genres = cache.get(cache_key)

        if cached_genres is not None:
            return Response(cached_genres, status=status.HTTP_200_OK)

        client = YTClient()
        genres = client.get_genres()
        serializer = GenreSerializer(genres, many=True)

        # Cache genres for 24 hours
        cache.set(cache_key, serializer.data, 86400)
        return Response(serializer.data, status=status.HTTP_200_OK)


class DeezerProxyView(APIView):
    """
    CORS-safe server-side proxy for Deezer and iTunes public catalog endpoints
    used by the Flutter Web client.
    """
    permission_classes = [permissions.AllowAny]

    ALLOWED_PREFIXES = (
        'https://api.deezer.com/',
        'https://itunes.apple.com/',
    )

    def get(self, request):
        target_url = (request.query_params.get('url') or '').strip()
        if not target_url or not any(target_url.startswith(p) for p in self.ALLOWED_PREFIXES):
            return Response(
                {'error': {'code': 'INVALID_PROXY_URL', 'message': 'URL cible non autorisée.'}},
                status=status.HTTP_400_BAD_REQUEST,
            )

        parsed = urllib.parse.urlsplit(target_url)
        if parsed.scheme != 'https' or parsed.netloc not in ('api.deezer.com', 'itunes.apple.com'):
            return Response(
                {'error': {'code': 'INVALID_PROXY_HOST', 'message': 'Hôte cible non autorisé.'}},
                status=status.HTTP_400_BAD_REQUEST,
            )

        digest = hashlib.sha256(target_url.encode('utf-8')).hexdigest()
        cache_key = f'deezer_proxy_{digest}'
        cached_payload = cache.get(cache_key)
        if cached_payload is not None:
            return Response(cached_payload, status=status.HTTP_200_OK)

        try:
            req = urllib.request.Request(
                target_url,
                headers={
                    'Accept': 'application/json',
                    'User-Agent': 'Sonoritiz/1.0 (+https://sonoritiz.vercel.app)',
                },
            )
            with urllib.request.urlopen(req, timeout=8) as resp:
                raw = resp.read().decode('utf-8')
                data = json.loads(raw)
        except Exception as exc:
            return Response(
                {'error': {'code': 'UPSTREAM_ERROR', 'message': str(exc)}},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        # Les endpoints /track/ contiennent un jeton preview signé (15 min) : TTL court (4 min)
        ttl = 240 if '/track/' in parsed.path else 900
        cache.set(cache_key, data, ttl)
        return Response(data, status=status.HTTP_200_OK)


class YoutubeStreamProxyView(APIView):
    """
    Resolves and streams the full-length YouTube progressive stream (itag 18)
    for Flutter Web clients so browsers play the complete track instead of
    30-second Deezer previews.
    """
    permission_classes = [permissions.AllowAny]

    ANDROID_UA = 'com.google.android.youtube/19.29.37 (Linux; U; Android 11) gzip'
    VID_REGEX = re.compile(r'^[a-zA-Z0-9_-]{11}$')

    @classmethod
    def _resolve_video_id(cls, query: str) -> str:
        cache_key = f'yt_vid_q_{hashlib.sha256(query.lower().encode("utf-8")).hexdigest()[:24]}'
        cached_vid = cache.get(cache_key)
        if cached_vid:
            return cached_vid

        # 1. InnerTube search
        try:
            payload = json.dumps({
                'context': {
                    'client': {
                        'clientName': 'ANDROID',
                        'clientVersion': '19.29.37',
                        'androidSdkVersion': 30,
                        'hl': 'fr',
                        'gl': 'FR',
                    }
                },
                'query': query,
            }).encode('utf-8')
            req = urllib.request.Request(
                'https://www.youtube.com/youtubei/v1/search?prettyPrint=false',
                data=payload,
                headers={
                    'Content-Type': 'application/json',
                    'User-Agent': cls.ANDROID_UA,
                },
                method='POST',
            )
            with urllib.request.urlopen(req, timeout=6) as resp:
                raw = resp.read().decode('utf-8', errors='replace')
            matches = re.findall(r'"videoId"\s*:\s*"([a-zA-Z0-9_-]{11})"', raw)
            if matches:
                vid = matches[0]
                cache.set(cache_key, vid, 86400)
                return vid
        except Exception:
            pass

        # 2. Fallback via YTClient (ytmusicapi)
        try:
            client = YTClient()
            results = client.search_tracks(query=query, limit=1, offset=0)
            if results and results[0].get('youtube_id'):
                vid = str(results[0]['youtube_id'])
                cache.set(cache_key, vid, 86400)
                return vid
        except Exception:
            pass
        return ''

    @classmethod
    def _resolve_itag18_url(cls, video_id: str) -> str:
        cache_key = f'yt_itag18_{video_id}'
        cached_url = cache.get(cache_key)
        if cached_url:
            return cached_url

        # 1. InnerTube ANDROID player endpoint (itag 18 progressive MP4, no PO-token required)
        try:
            payload = json.dumps({
                'context': {
                    'client': {
                        'clientName': 'ANDROID',
                        'clientVersion': '19.29.37',
                        'androidSdkVersion': 30,
                        'hl': 'fr',
                        'gl': 'FR',
                    }
                },
                'videoId': video_id,
                'contentCheckOk': True,
                'racyCheckOk': True,
            }).encode('utf-8')
            req = urllib.request.Request(
                'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
                data=payload,
                headers={
                    'Content-Type': 'application/json',
                    'User-Agent': cls.ANDROID_UA,
                },
                method='POST',
            )
            with urllib.request.urlopen(req, timeout=6) as resp:
                data = json.loads(resp.read().decode('utf-8'))

            streaming_data = data.get('streamingData') or {}
            formats = streaming_data.get('formats') or []
            for fmt in formats:
                if fmt.get('itag') == 18 and fmt.get('url'):
                    url = str(fmt['url'])
                    cache.set(cache_key, url, 3600)
                    return url
            for fmt in formats:
                if fmt.get('url'):
                    url = str(fmt['url'])
                    cache.set(cache_key, url, 3600)
                    return url
        except Exception:
            pass

        return ''

    def get(self, request):
        video_id = (request.query_params.get('video_id') or '').strip()
        query = (request.query_params.get('q') or '').strip()

        if not self.VID_REGEX.match(video_id):
            if not query:
                return Response(
                    {'error': {'code': 'MISSING_QUERY', 'message': 'Paramètre q ou video_id requis.'}},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            video_id = self._resolve_video_id(query)

        if not video_id:
            return Response(
                {'error': {'code': 'VIDEO_NOT_FOUND', 'message': 'Aucun flux trouvé pour ce titre.'}},
                status=status.HTTP_404_NOT_FOUND,
            )

        stream_url = self._resolve_itag18_url(video_id)
        if not stream_url:
            return Response(
                {'error': {'code': 'STREAM_UNAVAILABLE', 'message': 'Flux itag 18 indisponible.'}},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        if request.query_params.get('json') == '1':
            return Response({'video_id': video_id, 'stream_url': stream_url}, status=status.HTTP_200_OK)

        headers = {'User-Agent': self.ANDROID_UA}
        range_header = request.META.get('HTTP_RANGE')
        if range_header:
            headers['Range'] = range_header

        try:
            upstream_req = urllib.request.Request(stream_url, headers=headers)
            upstream_resp = urllib.request.urlopen(upstream_req, timeout=12)
        except Exception as exc:
            return Response(
                {'error': {'code': 'UPSTREAM_STREAM_ERROR', 'message': str(exc)}},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        def chunk_iterator():
            try:
                while True:
                    chunk = upstream_resp.read(65536)
                    if not chunk:
                        break
                    yield chunk
            finally:
                try:
                    upstream_resp.close()
                except Exception:
                    pass

        status_code = getattr(upstream_resp, 'status', 200) or 200
        content_type = upstream_resp.headers.get('Content-Type', 'audio/mp4')
        response = StreamingHttpResponse(
            chunk_iterator(),
            status=status_code,
            content_type=content_type,
        )
        response['Accept-Ranges'] = 'bytes'
        response['Access-Control-Allow-Origin'] = '*'
        for hdr in ('Content-Length', 'Content-Range'):
            val = upstream_resp.headers.get(hdr)
            if val:
                response[hdr] = val
        return response


