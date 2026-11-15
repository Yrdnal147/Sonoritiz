from rest_framework import serializers
from .models import Favorite
from catalog.utils import serialize_track_cache_item


class FavoriteSerializer(serializers.ModelSerializer):
    track_details = serializers.SerializerMethodField()

    class Meta:
        model = Favorite
        fields = ('id', 'youtube_id', 'added_at', 'track_details')
        read_only_fields = ('id', 'added_at', 'track_details')

    def get_track_details(self, obj):
        return serialize_track_cache_item(
            obj.youtube_id,
            self.context.get('track_cache_map'),
        )

class FavoriteCreateSerializer(serializers.Serializer):
    youtube_id = serializers.CharField()
    # Optional track metadata for caching
    title = serializers.CharField(required=False, default='')
    artist_name = serializers.CharField(required=False, default='')
    album_name = serializers.CharField(required=False, default='')
    cover_url = serializers.CharField(required=False, default='')
    duration_seconds = serializers.IntegerField(required=False, default=0)
