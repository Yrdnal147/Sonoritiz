from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
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
        payload = {"jamendo_track_id": "1001"}
        response = self.client.post(self.list_create_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(Favorite.objects.filter(user=self.user, jamendo_track_id="1001").exists())

    def test_list_favorites(self):
        Favorite.objects.create(user=self.user, jamendo_track_id="1002")
        response = self.client.get(self.list_create_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("results", response.data)
        self.assertEqual(len(response.data["results"]), 1)

    def test_delete_favorite(self):
        favorite = Favorite.objects.create(user=self.user, jamendo_track_id="1003")
        delete_url = reverse('favorite_detail', kwargs={'pk': favorite.id})
        response = self.client.delete(delete_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Favorite.objects.filter(id=favorite.id).exists())
