from .models import TrackCache
from .serializers import TrackSerializer


def build_track_cache_map(youtube_ids):
    """Fetch TrackCache rows for the given YouTube IDs in a single query."""
    unique_ids = list({str(yid) for yid in youtube_ids if yid})
    if not unique_ids:
        return {}
    return {
        cached_track.youtube_id: cached_track
        for cached_track in TrackCache.objects.filter(youtube_id__in=unique_ids)
    }


def serialize_track_cache_item(youtube_id, track_cache_map=None):
    """Serialize a cached track, using a preloaded map when provided to avoid N+1 queries."""
    if not youtube_id:
        return None

    key = str(youtube_id)
    if track_cache_map is not None:
        cached_track = track_cache_map.get(key)
    else:
        cached_track = TrackCache.objects.filter(youtube_id=key).first()

    if cached_track is None:
        return None

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
