from rest_framework import serializers
from .models import TrackCache

class TrackSerializer(serializers.Serializer):
    youtube_id = serializers.CharField()
    title = serializers.CharField()
    artist_name = serializers.CharField()
    album_name = serializers.CharField(allow_blank=True, required=False, default='')
    cover_url = serializers.CharField(allow_blank=True, required=False, default='')
    duration_seconds = serializers.IntegerField(default=0)
    audio_url = serializers.CharField(allow_blank=True, required=False, default='')
    genre = serializers.CharField(allow_blank=True, required=False, default='')
    license_ccurl = serializers.CharField(allow_blank=True, required=False, default='')

class GenreSerializer(serializers.Serializer):
    id = serializers.CharField()
    name = serializers.CharField()
