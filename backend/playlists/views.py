from django.db.models import prefetch_related_objects
from rest_framework import status, permissions, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.pagination import LimitOffsetPagination
from .models import Playlist, PlaylistTrack
from catalog.models import TrackCache
from catalog.utils import build_track_cache_map
from .serializers import (
    PlaylistSerializer,
    PlaylistCreateUpdateSerializer,
    PlaylistTrackAddSerializer,
)


def _serialize_playlist_with_prefetched_tracks(playlist):
    prefetch_related_objects([playlist], 'tracks')
    track_cache_map = build_track_cache_map(
        track.youtube_id for track in playlist.tracks.all()
    )
    return PlaylistSerializer(
        playlist,
        context={'track_cache_map': track_cache_map},
    ).data


class PlaylistsPagination(LimitOffsetPagination):
    default_limit = 20
    max_limit = 50


class PlaylistsListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        playlists = Playlist.objects.filter(user=request.user).prefetch_related('tracks')
        paginator = PlaylistsPagination()
        paginated_playlists = paginator.paginate_queryset(playlists, request, view=self)
        track_cache_map = build_track_cache_map(
            track.youtube_id
            for playlist in (paginated_playlists or [])
            for track in playlist.tracks.all()
        )
        serializer = PlaylistSerializer(
            paginated_playlists,
            many=True,
            context={'track_cache_map': track_cache_map},
        )
        return paginator.get_paginated_response(serializer.data)

    def post(self, request):
        serializer = PlaylistCreateUpdateSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)

        playlist = serializer.save(user=request.user)
        return Response(
            PlaylistSerializer(playlist, context={'track_cache_map': {}}).data,
            status=status.HTTP_201_CREATED,
        )


class PlaylistDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def _get_playlist(self, user, pk):
        try:
            return Playlist.objects.prefetch_related('tracks').get(user=user, pk=pk)
        except Playlist.DoesNotExist:
            return None

    def get(self, request, pk):
        playlist = self._get_playlist(request.user, pk)
        if not playlist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Playlist introuvable."}},
                status=status.HTTP_404_NOT_FOUND
            )
        return Response(_serialize_playlist_with_prefetched_tracks(playlist), status=status.HTTP_200_OK)

    def put(self, request, pk):
        playlist = self._get_playlist(request.user, pk)
        if not playlist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Playlist introuvable."}},
                status=status.HTTP_404_NOT_FOUND
            )
        serializer = PlaylistCreateUpdateSerializer(playlist, data=request.data, partial=True)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)
        playlist = serializer.save()
        return Response(_serialize_playlist_with_prefetched_tracks(playlist), status=status.HTTP_200_OK)

    def patch(self, request, pk):
        return self.put(request, pk)

    def delete(self, request, pk):
        playlist = self._get_playlist(request.user, pk)
        if not playlist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Playlist introuvable."}},
                status=status.HTTP_404_NOT_FOUND
            )
        playlist.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

class PlaylistTracksAddView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            playlist = Playlist.objects.get(user=request.user, pk=pk)
        except Playlist.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Playlist introuvable."}},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = PlaylistTrackAddSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)

        youtube_id = serializer.validated_data['youtube_id']
        position = serializer.validated_data.get('position', 0)

        # Cache track metadata in TrackCache if title is provided
        title = serializer.validated_data.get('title', '')
        if title:
            TrackCache.objects.update_or_create(
                youtube_id=youtube_id,
                defaults={
                    'title': title,
                    'artist_name': serializer.validated_data.get('artist_name', ''),
                    'album_name': serializer.validated_data.get('album_name', ''),
                    'cover_url': serializer.validated_data.get('cover_url', ''),
                    'duration_seconds': serializer.validated_data.get('duration_seconds', 0),
                    'audio_url': '',
                    'genre': '',
                    'license_ccurl': '',
                }
            )

        if position == 0:
            last_pos = playlist.tracks.count()
            position = last_pos + 1

        track_item, created = PlaylistTrack.objects.get_or_create(
            playlist=playlist,
            youtube_id=youtube_id,
            defaults={'position': position}
        )
        if not created:
            track_item.position = position
            track_item.save()

        return Response(_serialize_playlist_with_prefetched_tracks(playlist), status=status.HTTP_200_OK)

class PlaylistTrackDeleteView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, pk, track_id):
        try:
            playlist = Playlist.objects.get(user=request.user, pk=pk)
            track_item = PlaylistTrack.objects.get(playlist=playlist, youtube_id=str(track_id))
            track_item.delete()
            return Response(_serialize_playlist_with_prefetched_tracks(playlist), status=status.HTTP_200_OK)
        except (Playlist.DoesNotExist, PlaylistTrack.DoesNotExist):
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Élément introuvable."}},
                status=status.HTTP_404_NOT_FOUND
            )
