from rest_framework import serializers
from .models import ListeningHistory
from catalog.utils import serialize_track_cache_item


class ListeningHistorySerializer(serializers.ModelSerializer):
    track_details = serializers.SerializerMethodField()

    class Meta:
        model = ListeningHistory
        fields = ('id', 'youtube_id', 'played_at', 'track_details')
        read_only_fields = ('id', 'played_at', 'track_details')

    def get_track_details(self, obj):
        return serialize_track_cache_item(
            obj.youtube_id,
            self.context.get('track_cache_map'),
        )

class ListeningHistoryCreateSerializer(serializers.Serializer):
    youtube_id = serializers.CharField(max_length=64)
    track_data = serializers.JSONField(required=False)
