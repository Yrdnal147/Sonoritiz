from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
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
        response = self.client.post(add_track_url, {"jamendo_track_id": "505"}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["tracks_count"], 1)

        # Remove track
        delete_track_url = reverse('playlist_track_delete', kwargs={'pk': playlist.id, 'track_id': '505'})
        response = self.client.delete(delete_track_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["tracks_count"], 0)
