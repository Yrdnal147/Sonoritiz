from django.db import models

class TrackCache(models.Model):
    youtube_id = models.CharField(max_length=64, unique=True, db_index=True)
    title = models.CharField(max_length=255)
    artist_name = models.CharField(max_length=255)
    album_name = models.CharField(max_length=255, blank=True, default='')
    cover_url = models.URLField(max_length=500, blank=True, default='')
    duration_seconds = models.IntegerField(default=0)
    audio_url = models.URLField(max_length=500, blank=True, default='')
    genre = models.CharField(max_length=100, blank=True, default='')
    license_ccurl = models.URLField(max_length=500, blank=True, default='')
    cached_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-cached_at']

    def __str__(self):
        return f"{self.title} - {self.artist_name} (YouTube ID: {self.youtube_id})"
