from rest_framework import serializers
from .models import Favorite
from catalog.models import TrackCache
from catalog.serializers import TrackSerializer

class FavoriteSerializer(serializers.ModelSerializer):
    track_details = serializers.SerializerMethodField()

    class Meta:
        model = Favorite
        fields = ('id', 'youtube_id', 'added_at', 'track_details')
        read_only_fields = ('id', 'added_at', 'track_details')

    def get_track_details(self, obj):
        try:
            cached_track = TrackCache.objects.get(youtube_id=obj.youtube_id)
            return TrackSerializer({
                "youtube_id": cached_track.youtube_id,
                "title": cached_track.title,
                "artist_name": cached_track.artist_name,
                "album_name": cached_track.album_name,
                "cover_url": cached_track.cover_url,
                "duration_seconds": cached_track.duration_seconds,
                "audio_url": cached_track.audio_url,
                "genre": cached_track.genre,
                "license_ccurl": cached_track.license_ccurl,
            }).data
        except TrackCache.DoesNotExist:
            return None

class FavoriteCreateSerializer(serializers.Serializer):
    youtube_id = serializers.CharField()
    # Optional track metadata for caching
    title = serializers.CharField(required=False, default='')
    artist_name = serializers.CharField(required=False, default='')
    album_name = serializers.CharField(required=False, default='')
    cover_url = serializers.CharField(required=False, default='')
    duration_seconds = serializers.IntegerField(required=False, default=0)
