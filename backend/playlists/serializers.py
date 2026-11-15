from rest_framework import serializers
from .models import Playlist, PlaylistTrack
from catalog.utils import serialize_track_cache_item


class PlaylistTrackSerializer(serializers.ModelSerializer):
    track_details = serializers.SerializerMethodField()

    class Meta:
        model = PlaylistTrack
        fields = ('id', 'youtube_id', 'position', 'added_at', 'track_details')

    def get_track_details(self, obj):
        return serialize_track_cache_item(
            obj.youtube_id,
            self.context.get('track_cache_map'),
        )


class PlaylistSerializer(serializers.ModelSerializer):
    tracks = PlaylistTrackSerializer(many=True, read_only=True)
    tracks_count = serializers.SerializerMethodField()

    class Meta:
        model = Playlist
        fields = ('id', 'name', 'cover_url', 'is_pinned', 'created_at', 'updated_at', 'tracks_count', 'tracks')
        read_only_fields = ('id', 'created_at', 'updated_at')

    def get_tracks_count(self, obj):
        prefetched = getattr(obj, '_prefetched_objects_cache', None)
        if prefetched and 'tracks' in prefetched:
            return len(prefetched['tracks'])
        return obj.tracks.count()

class PlaylistCreateUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Playlist
        fields = ('name', 'cover_url', 'is_pinned')

class PlaylistTrackAddSerializer(serializers.Serializer):
    youtube_id = serializers.CharField()
    position = serializers.IntegerField(required=False, default=0)
    # Optional track metadata for caching
    title = serializers.CharField(required=False, default='')
    artist_name = serializers.CharField(required=False, default='')
    album_name = serializers.CharField(required=False, default='')
    cover_url = serializers.CharField(required=False, default='')
    duration_seconds = serializers.IntegerField(required=False, default=0)
