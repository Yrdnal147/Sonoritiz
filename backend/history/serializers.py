from rest_framework import serializers
from .models import ListeningHistory
from catalog.models import TrackCache
from catalog.serializers import TrackSerializer

class ListeningHistorySerializer(serializers.ModelSerializer):
    track_details = serializers.SerializerMethodField()

    class Meta:
        model = ListeningHistory
        fields = ('id', 'youtube_id', 'played_at', 'track_details')
        read_only_fields = ('id', 'played_at', 'track_details')

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

class ListeningHistoryCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ListeningHistory
        fields = ('youtube_id',)
