import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sonoritiz_backend.settings')
import django
django.setup()

from catalog.services import JamendoClient

client = JamendoClient()
tracks = client.get_trending_tracks(limit=3)
print(f"Got {len(tracks)} tracks from Jamendo")
for t in tracks:
    print(f"  Title: {t['title']}")
    print(f"  Artist: {t['artist_name']}")
    print(f"  Audio URL: {t['audio_url'][:80] if t['audio_url'] else 'EMPTY!'}")
    print(f"  Cover URL: {t['cover_url'][:80] if t['cover_url'] else 'EMPTY!'}")
    print(f"  Duration: {t['duration_seconds']}s")
    print(f"  License: {t['license_ccurl']}")
    print("---")
