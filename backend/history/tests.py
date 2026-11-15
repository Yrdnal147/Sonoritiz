from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from catalog.models import TrackCache
from history.models import ListeningHistory

User = get_user_model()

class HistoryEndpointsTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="histuser@sonoritiz.com",
            username="histuser",
            password="Password123!"
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.list_create_url = reverse('history_list_create')

    def test_record_history(self):
        payload = {"youtube_id": "yt_707"}
        response = self.client.post(self.list_create_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(ListeningHistory.objects.filter(user=self.user, youtube_id="yt_707").exists())

    def test_list_history(self):
        ListeningHistory.objects.create(user=self.user, youtube_id="yt_708")
        response = self.client.get(self.list_create_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("results", response.data)
        self.assertEqual(len(response.data["results"]), 1)

    def test_list_history_avoids_n_plus_one_queries(self):
        for idx in range(35):
            yid = f"hist_vid_{idx}"
            TrackCache.objects.create(
                youtube_id=yid,
                title=f"Hist Track {idx}",
                artist_name="Artist",
                duration_seconds=210,
            )
            ListeningHistory.objects.create(user=self.user, youtube_id=yid)

        with self.assertNumQueries(3):
            response = self.client.get(f"{self.list_create_url}?limit=50")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 35)
        self.assertIsNotNone(response.data["results"][0]["track_details"])
