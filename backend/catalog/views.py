from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.pagination import LimitOffsetPagination
from django.core.cache import cache
from .services.yt_client import YTClient
from .models import TrackCache
from .serializers import TrackSerializer, GenreSerializer

class CatalogPagination(LimitOffsetPagination):
    default_limit = 20
    max_limit = 50

def cache_or_update_tracks(tracks_data):
    """Helper utility to persist tracks into database TrackCache for offline/instant lookup."""
    for track in tracks_data:
        if not track.get('youtube_id'):
            continue
        TrackCache.objects.update_or_create(
            youtube_id=str(track['youtube_id']),
            defaults={
                'title': track.get('title', ''),
                'artist_name': track.get('artist_name', ''),
                'album_name': track.get('album_name', ''),
                'cover_url': track.get('cover_url', ''),
                'duration_seconds': int(track.get('duration_seconds', 0)),
                'audio_url': track.get('audio_url', ''),
                'genre': track.get('genre', ''),
                'license_ccurl': track.get('license_ccurl', ''),
            }
        )

class TrendingTracksView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        limit = int(request.query_params.get('limit', 20))
        offset = int(request.query_params.get('offset', 0))

        cache_key = f"trending_tracks_{limit}_{offset}"
        cached_data = cache.get(cache_key)

        if cached_data is not None:
            return Response(cached_data, status=status.HTTP_200_OK)

        client = YTClient()
        tracks = client.get_trending_tracks(limit=limit, offset=offset)
        cache_or_update_tracks(tracks)

        paginator = CatalogPagination()
        paginated_tracks = paginator.paginate_queryset(tracks, request, view=self)

        response_data = paginator.get_paginated_response(
            TrackSerializer(paginated_tracks, many=True).data
        ).data

        # Cache response for 1 hour (3600s) to strictly conserve Jamendo API quota
        cache.set(cache_key, response_data, 3600)
        return Response(response_data, status=status.HTTP_200_OK)

class SearchTracksView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        query = request.query_params.get('q', '').strip()
        genre = request.query_params.get('genre', '').strip()
        limit = int(request.query_params.get('limit', 20))
        offset = int(request.query_params.get('offset', 0))

        cache_key = f"search_tracks_{query}_{genre}_{limit}_{offset}"
        cached_data = cache.get(cache_key)

        if cached_data is not None:
            return Response(cached_data, status=status.HTTP_200_OK)

        client = YTClient()
        tracks = client.search_tracks(query=query, limit=limit, offset=offset, genre=genre)
        cache_or_update_tracks(tracks)

        paginator = CatalogPagination()
        paginated_tracks = paginator.paginate_queryset(tracks, request, view=self)

        response_data = paginator.get_paginated_response(
            TrackSerializer(paginated_tracks, many=True).data
        ).data

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
