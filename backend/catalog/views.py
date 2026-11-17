import hashlib
import json
import urllib.parse
import urllib.request
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

