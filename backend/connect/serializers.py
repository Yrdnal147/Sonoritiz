from django.contrib.auth import get_user_model
from rest_framework import serializers
from .models import ConnectSession, ConnectParticipant
from playlists.serializers import PlaylistSerializer

User = get_user_model()


class ConnectUserSummarySerializer(serializers.ModelSerializer):
    """Sérialiseur ultra-léger pour les salons Connect : n'expose et ne lit ni email ni colonnes JSON lourdes."""

    class Meta:
        model = User
        fields = ('id', 'username')
        read_only_fields = ('id', 'username')


class ConnectParticipantSerializer(serializers.ModelSerializer):
    user = ConnectUserSummarySerializer(read_only=True)

    class Meta:
        model = ConnectParticipant
        fields = ('id', 'user', 'joined_at')


class ConnectSessionSerializer(serializers.ModelSerializer):
    host_user = ConnectUserSummarySerializer(read_only=True)
    participants = ConnectParticipantSerializer(many=True, read_only=True)
    playlist = PlaylistSerializer(read_only=True)

    class Meta:
        model = ConnectSession
        fields = (
            'id',
            'host_user',
            'invite_code',
            'status',
            'current_jamendo_track_id',
            'playlist',
            'created_at',
            'participants',
        )
        read_only_fields = ('id', 'invite_code', 'host_user', 'created_at')


class ConnectJoinSerializer(serializers.Serializer):
    invite_code = serializers.CharField(max_length=10)
