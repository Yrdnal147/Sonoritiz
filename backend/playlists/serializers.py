from rest_framework import serializers
from .models import Playlist, PlaylistTrack
from catalog.models import TrackCache
from catalog.serializers import TrackSerializer

class PlaylistTrackSerializer(serializers.ModelSerializer):
    track_details = serializers.SerializerMethodField()

    class Meta:
        model = PlaylistTrack
        fields = ('id', 'youtube_id', 'position', 'added_at', 'track_details')

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

class PlaylistSerializer(serializers.ModelSerializer):
    tracks = PlaylistTrackSerializer(many=True, read_only=True)
    tracks_count = serializers.SerializerMethodField()

    class Meta:
        model = Playlist
        fields = ('id', 'name', 'cover_url', 'created_at', 'updated_at', 'tracks_count', 'tracks')
        read_only_fields = ('id', 'created_at', 'updated_at')

    def get_tracks_count(self, obj):
        return obj.tracks.count()

class PlaylistCreateUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Playlist
        fields = ('name', 'cover_url')

class PlaylistTrackAddSerializer(serializers.Serializer):
    youtube_id = serializers.CharField()
    position = serializers.IntegerField(required=False, default=0)
    # Optional track metadata for caching
    title = serializers.CharField(required=False, default='')
    artist_name = serializers.CharField(required=False, default='')
    album_name = serializers.CharField(required=False, default='')
    cover_url = serializers.CharField(required=False, default='')
    duration_seconds = serializers.IntegerField(required=False, default=0)
