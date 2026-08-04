from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from connect.models import ConnectSession, ConnectParticipant
from connect.consumers import ConnectConsumer

User = get_user_model()

class ConnectEndpointsTestCase(TestCase):
    def setUp(self):
        self.host_user = User.objects.create_user(
            email="host@sonoritiz.com",
            username="hostuser",
            password="Password123!"
        )
        self.guest_user = User.objects.create_user(
            email="guest@sonoritiz.com",
            username="guestuser",
            password="Password123!"
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.host_user)
        self.create_session_url = reverse('connect_session_create')

    def test_create_session(self):
        response = self.client.post(self.create_session_url, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn("invite_code", response.data)
        self.assertEqual(response.data["status"], "active")
        self.assertEqual(len(response.data["invite_code"]), 6)

    def test_join_session_success(self):
        # Host creates session
        response = self.client.post(self.create_session_url, format='json')
        invite_code = response.data["invite_code"]

        # Guest joins
        guest_client = APIClient()
        guest_client.force_authenticate(user=self.guest_user)
        join_url = reverse('connect_session_join')
        join_response = guest_client.post(join_url, {"invite_code": invite_code}, format='json')
        self.assertEqual(join_response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(join_response.data["participants"]), 2)

    def test_join_session_invalid_code(self):
        join_url = reverse('connect_session_join')
        response = self.client.post(join_url, {"invite_code": "INVALID"}, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_leave_session(self):
        session = ConnectSession.objects.create(host_user=self.host_user, status='active')
        ConnectParticipant.objects.create(session=session, user=self.host_user)
        
        leave_url = reverse('connect_session_leave', kwargs={'pk': session.id})
        response = self.client.post(leave_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        session.refresh_from_db()
        self.assertEqual(session.status, 'ended')
