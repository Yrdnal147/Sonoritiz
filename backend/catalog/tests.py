from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status
from unittest.mock import patch, MagicMock
from catalog.services import JamendoClient
from catalog.models import TrackCache

class CatalogEndpointsTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.trending_url = reverse('tracks_trending')
        self.search_url = reverse('tracks_search')
        self.genres_url = reverse('genres_list')

    @patch.object(JamendoClient, 'get_trending_tracks')
    def test_trending_tracks_endpoint(self, mock_trending):
        mock_trending.return_value = [
            {
                "jamendo_track_id": "101",
                "title": "Trending Track 1",
                "artist_name": "Artist 1",
                "album_name": "Album 1",
                "cover_url": "https://example.com/cover1.jpg",
                "duration_seconds": 200,
                "audio_url": "https://example.com/audio1.mp3",
                "genre": "Rock",
                "license_ccurl": "https://creativecommons.org/licenses/by/4.0/"
            }
        ]

        response = self.client.get(self.trending_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("results", response.data)
        self.assertEqual(len(response.data["results"]), 1)
        self.assertEqual(response.data["results"][0]["jamendo_track_id"], "101")
        self.assertTrue(TrackCache.objects.filter(jamendo_track_id="101").exists())

    @patch.object(JamendoClient, 'search_tracks')
    def test_search_tracks_endpoint(self, mock_search):
        mock_search.return_value = [
            {
                "jamendo_track_id": "202",
                "title": "Rock Track",
                "artist_name": "Rock Artist",
                "album_name": "Rock Album",
                "cover_url": "https://example.com/cover2.jpg",
                "duration_seconds": 180,
                "audio_url": "https://example.com/audio2.mp3",
                "genre": "Rock",
                "license_ccurl": "https://creativecommons.org/licenses/by/4.0/"
            }
        ]

        response = self.client.get(f"{self.search_url}?q=rock")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("results", response.data)
        self.assertEqual(response.data["results"][0]["title"], "Rock Track")

    def test_track_detail_cached_endpoint(self):
        TrackCache.objects.create(
            jamendo_track_id="303",
            title="Cached Track Detail",
            artist_name="Detail Artist",
            album_name="Detail Album",
            cover_url="https://example.com/cover3.jpg",
            duration_seconds=220,
            audio_url="https://example.com/audio3.mp3",
            genre="Pop",
            license_ccurl="https://creativecommons.org/licenses/by/4.0/"
        )

        detail_url = reverse('track_detail', kwargs={'track_id': '303'})
        response = self.client.get(detail_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["title"], "Cached Track Detail")
        self.assertEqual(response.data["audio_url"], "https://example.com/audio3.mp3")

    def test_genres_endpoint(self):
        response = self.client.get(self.genres_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIsInstance(response.data, list)
        self.assertTrue(len(response.data) > 0)
        self.assertIn("name", response.data[0])
