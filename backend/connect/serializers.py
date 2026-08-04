from rest_framework import serializers
from .models import ConnectSession, ConnectParticipant
from accounts.serializers import UserSerializer
from playlists.serializers import PlaylistSerializer

class ConnectParticipantSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = ConnectParticipant
        fields = ('id', 'user', 'joined_at')

class ConnectSessionSerializer(serializers.ModelSerializer):
    host_user = UserSerializer(read_only=True)
    participants = ConnectParticipantSerializer(many=True, read_only=True)
    playlist = PlaylistSerializer(read_only=True)

    class Meta:
        model = ConnectSession
        fields = (
            'id', 'host_user', 'invite_code', 'status',
            'current_jamendo_track_id', 'playlist', 'created_at',
            'participants'
        )
        read_only_fields = ('id', 'invite_code', 'host_user', 'created_at')

class ConnectJoinSerializer(serializers.Serializer):
    invite_code = serializers.CharField(max_length=10)
