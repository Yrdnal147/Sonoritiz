from rest_framework import status, permissions, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.pagination import LimitOffsetPagination
from .models import ListeningHistory
from .serializers import ListeningHistorySerializer, ListeningHistoryCreateSerializer
from catalog.models import TrackCache
from catalog.utils import build_track_cache_map

class HistoryPagination(LimitOffsetPagination):
    default_limit = 20
    max_limit = 50

class HistoryListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        history = ListeningHistory.objects.filter(user=request.user)
        paginator = HistoryPagination()
        paginated_history = paginator.paginate_queryset(history, request, view=self)
        track_cache_map = build_track_cache_map(
            item.youtube_id for item in (paginated_history or [])
        )
        serializer = ListeningHistorySerializer(
            paginated_history,
            many=True,
            context={'track_cache_map': track_cache_map},
        )
        return paginator.get_paginated_response(serializer.data)

    def post(self, request):
        serializer = ListeningHistoryCreateSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)

        youtube_id = serializer.validated_data['youtube_id']
        track_data = serializer.validated_data.get('track_data')
        if isinstance(track_data, dict) and track_data.get('title'):
            defaults = {
                'title': str(track_data.get('title', '')),
                'artist_name': str(track_data.get('artist_name', '')),
                'album_name': str(track_data.get('album_name', '')),
                'cover_url': str(track_data.get('cover_url', '')),
                'duration_seconds': int(track_data.get('duration_seconds') or 0),
                'genre': str(track_data.get('genre', '')),
                'license_ccurl': str(track_data.get('license_ccurl', '')),
            }
            audio_url = str(track_data.get('audio_url', '')).strip()
            if audio_url:
                defaults['audio_url'] = audio_url
            TrackCache.objects.update_or_create(
                youtube_id=youtube_id,
                defaults=defaults,
            )

        history_item = ListeningHistory.objects.create(user=request.user, youtube_id=youtube_id)
        return Response(ListeningHistorySerializer(history_item).data, status=status.HTTP_201_CREATED)
