from django.db import models
from django.conf import settings

class ListeningHistory(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='history')
    youtube_id = models.CharField(max_length=64)
    played_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-played_at']

    def __str__(self):
        return f"{self.user.username} listened to track {self.youtube_id} at {self.played_at}"
