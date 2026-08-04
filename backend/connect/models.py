import secrets
import string
from django.db import models
from django.conf import settings

def generate_invite_code():
    chars = string.ascii_uppercase + string.digits
    return ''.join(secrets.choice(chars) for _ in range(6))

class ConnectSession(models.Model):
    STATUS_CHOICES = (
        ('waiting', 'Waiting'),
        ('active', 'Active'),
        ('ended', 'Ended'),
    )

    host_user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='hosted_connect_sessions')
    invite_code = models.CharField(max_length=10, unique=True, default=generate_invite_code, db_index=True)
    status = models.CharField(max_length=15, choices=STATUS_CHOICES, default='waiting')
    current_jamendo_track_id = models.CharField(max_length=64, blank=True, default='')
    playlist = models.ForeignKey('playlists.Playlist', on_delete=models.SET_NULL, null=True, blank=True, related_name='connect_sessions')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Connect Session {self.invite_code} by {self.host_user.username} ({self.status})"

class ConnectParticipant(models.Model):
    session = models.ForeignKey(ConnectSession, on_delete=models.CASCADE, related_name='participants')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='connect_participations')
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('session', 'user')

    def __str__(self):
        return f"{self.user.username} in session {self.session.invite_code}"
