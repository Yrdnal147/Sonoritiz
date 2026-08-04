from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
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
        payload = {"jamendo_track_id": "707"}
        response = self.client.post(self.list_create_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(ListeningHistory.objects.filter(user=self.user, jamendo_track_id="707").exists())

    def test_list_history(self):
        ListeningHistory.objects.create(user=self.user, jamendo_track_id="708")
        response = self.client.get(self.list_create_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("results", response.data)
        self.assertEqual(len(response.data["results"]), 1)
