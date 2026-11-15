from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from catalog.models import TrackCache
from playlists.models import Playlist, PlaylistTrack

User = get_user_model()

class PlaylistsEndpointsTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="playlistuser@sonoritiz.com",
            username="playlistuser",
            password="Password123!"
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.list_create_url = reverse('playlists_list_create')

    def test_create_playlist(self):
        payload = {"name": "Ma Playlist Rock", "cover_url": "https://example.com/cover.jpg"}
        response = self.client.post(self.list_create_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["name"], "Ma Playlist Rock")
        self.assertTrue(Playlist.objects.filter(user=self.user, name="Ma Playlist Rock").exists())

    def test_add_and_remove_track_to_playlist(self):
        playlist = Playlist.objects.create(user=self.user, name="Workout")
        add_track_url = reverse('playlist_tracks_add', kwargs={'pk': playlist.id})
        
        # Add track
        response = self.client.post(add_track_url, {"youtube_id": "yt_505"}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["tracks_count"], 1)

        # Remove track
        delete_track_url = reverse('playlist_track_delete', kwargs={'pk': playlist.id, 'track_id': 'yt_505'})
        response = self.client.delete(delete_track_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["tracks_count"], 0)

    def test_list_playlists_avoids_n_plus_one_queries(self):
        for p_idx in range(14):
            playlist = Playlist.objects.create(user=self.user, name=f"Playlist {p_idx}")
            for t_idx in range(25):
                yid = f"vid_{p_idx}_{t_idx}"
                TrackCache.objects.create(
                    youtube_id=yid,
                    title=f"Title {p_idx}-{t_idx}",
                    artist_name="Artist",
                    duration_seconds=180,
                )
                PlaylistTrack.objects.create(
                    playlist=playlist,
                    youtube_id=yid,
                    position=t_idx + 1,
                )

        # Constant query count: count + playlists + prefetched tracks + bulk TrackCache
        with self.assertNumQueries(4):
            response = self.client.get(f"{self.list_create_url}?limit=50")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 14)
        self.assertEqual(response.data["results"][0]["tracks_count"], 25)
        self.assertIsNotNone(response.data["results"][0]["tracks"][0]["track_details"])
