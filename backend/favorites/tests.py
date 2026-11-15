from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from catalog.models import TrackCache
from favorites.models import Favorite

User = get_user_model()

class FavoritesEndpointsTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="favuser@sonoritiz.com",
            username="favuser",
            password="Password123!"
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.list_create_url = reverse('favorites_list_create')

    def test_add_favorite(self):
        payload = {"youtube_id": "yt_1001"}
        response = self.client.post(self.list_create_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(Favorite.objects.filter(user=self.user, youtube_id="yt_1001").exists())

    def test_list_favorites(self):
        Favorite.objects.create(user=self.user, youtube_id="yt_1002")
        response = self.client.get(self.list_create_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("results", response.data)
        self.assertEqual(len(response.data["results"]), 1)

    def test_delete_favorite(self):
        favorite = Favorite.objects.create(user=self.user, youtube_id="yt_1003")
        delete_url = reverse('favorite_detail', kwargs={'pk': favorite.id})
        response = self.client.delete(delete_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Favorite.objects.filter(id=favorite.id).exists())

    def test_list_favorites_avoids_n_plus_one_queries(self):
        for idx in range(35):
            yid = f"fav_vid_{idx}"
            TrackCache.objects.create(
                youtube_id=yid,
                title=f"Fav Track {idx}",
                artist_name="Artist",
                duration_seconds=200,
            )
            Favorite.objects.create(user=self.user, youtube_id=yid)

        with self.assertNumQueries(3):
            response = self.client.get(f"{self.list_create_url}?limit=50")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 35)
        self.assertIsNotNone(response.data["results"][0]["track_details"])
