import requests
from django.conf import settings
import logging

logger = logging.getLogger(__name__)

class JamendoClient:
    """
    Python client encapsulation for Jamendo API v3.0.
    Handles communication with Jamendo API, fallback formatting, and error handling.
    """
    BASE_URL = "https://api.jamendo.com/v3.0"

    def __init__(self, client_id=None):
        self.client_id = client_id or getattr(settings, 'JAMENDO_CLIENT_ID', '567b5e40')

    def _get(self, endpoint, params=None):
        if params is None:
            params = {}

        params['client_id'] = self.client_id
        params['format'] = 'json'

        url = f"{self.BASE_URL}/{endpoint.lstrip('/')}"
        try:
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()

            # Check Jamendo API header status
            headers = data.get('headers', {})
            if headers.get('status') == 'failed':
                error_msg = headers.get('error_message', 'Jamendo API failure response')
                logger.error(f"Jamendo API returned failed status: {error_msg}")
                return None

            return data.get('results', [])
        except requests.RequestException as e:
            logger.error(f"HTTP request error querying Jamendo endpoint {endpoint}: {e}")
            return None

    def search_tracks(self, query=None, limit=20, offset=0, genre=None):
        """Search tracks by text query or genre."""
        params = {
            'limit': limit,
            'offset': offset,
            'audioformat': 'mp32',  # 192kbps MP3 preference
            'include': 'licenses',
        }
        if query:
            params['search'] = query
        if genre:
            params['tags'] = genre

        results = self._get('/tracks/', params)
        if results is None:
            # Fallback to 96kbps if 192kbps fails
            params['audioformat'] = 'mp31'
            results = self._get('/tracks/', params) or []

        return [self._format_track(t) for t in results]

    def get_trending_tracks(self, limit=20, offset=0):
        """Fetch trending / popular tracks."""
        params = {
            'limit': limit,
            'offset': offset,
            'order': 'popularity_week',
            'audioformat': 'mp32',
            'include': 'licenses',
        }
        results = self._get('/tracks/', params)
        if results is None:
            params['audioformat'] = 'mp31'
            results = self._get('/tracks/', params) or []

        return [self._format_track(t) for t in results]

    def get_track_detail(self, track_id):
        """Fetch a single track details by ID."""
        params = {
            'id': track_id,
            'audioformat': 'mp32',
            'include': 'licenses',
        }
        results = self._get('/tracks/', params)
        if not results:
            params['audioformat'] = 'mp31'
            results = self._get('/tracks/', params)

        if results and len(results) > 0:
            return self._format_track(results[0])
        return None

    def get_genres(self):
        """Fetch preset default genres list."""
        return [
            {"id": "rock", "name": "Rock"},
            {"id": "pop", "name": "Pop"},
            {"id": "jazz", "name": "Jazz"},
            {"id": "electronic", "name": "Électronique"},
            {"id": "hiphop", "name": "Hip-Hop"},
            {"id": "classical", "name": "Classique"},
            {"id": "ambient", "name": "Ambient"},
            {"id": "metal", "name": "Metal"},
            {"id": "indie", "name": "Indie"},
            {"id": "folk", "name": "Folk"},
        ]

    def _format_track(self, raw_track):
        """Standardize raw Jamendo track dict into clean normalized representation."""
        audio_url = raw_track.get('audio') or raw_track.get('audiodownload', '')

        # License CC URL extractions
        license_ccurl = raw_track.get('license_ccurl', '')
        if not license_ccurl and 'licenses' in raw_track:
            licenses = raw_track.get('licenses', [])
            if len(licenses) > 0:
                license_ccurl = licenses[0].get('url', '')

        return {
            "jamendo_track_id": str(raw_track.get('id', '')),
            "title": raw_track.get('name', 'Titre inconnu'),
            "artist_name": raw_track.get('artist_name', 'Artiste inconnu'),
            "album_name": raw_track.get('album_name', 'Album inconnu'),
            "cover_url": raw_track.get('album_image') or raw_track.get('image', ''),
            "duration_seconds": int(raw_track.get('duration', 0)),
            "audio_url": audio_url,
            "genre": raw_track.get('musicinfo', {}).get('tags', {}).get('genres', [''])[0] if raw_track.get('musicinfo') else '',
            "license_ccurl": license_ccurl or 'https://creativecommons.org/licenses/by/4.0/',
        }
