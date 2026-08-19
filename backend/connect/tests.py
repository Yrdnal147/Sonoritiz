from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from connect.models import ConnectSession, ConnectParticipant
from playlists.models import Playlist
import json
import asyncio

# Channels testing
from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from sonoritiz_backend.asgi import application
from rest_framework_simplejwt.tokens import AccessToken

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
        self.stranger_user = User.objects.create_user(
            email="stranger@sonoritiz.com",
            username="strangeruser",
            password="Password123!"
        )
        self.host_client = APIClient()
        self.host_client.force_authenticate(user=self.host_user)
        
        self.guest_client = APIClient()
        self.guest_client.force_authenticate(user=self.guest_user)

        self.stranger_client = APIClient()
        self.stranger_client.force_authenticate(user=self.stranger_user)

        self.create_session_url = reverse('connect_session_create')

        # Playlists
        self.host_playlist = Playlist.objects.create(name="Host PL", user=self.host_user)
        self.stranger_playlist = Playlist.objects.create(name="Stranger PL", user=self.stranger_user)

    def test_create_session(self):
        response = self.host_client.post(self.create_session_url, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn("invite_code", response.data)
        self.assertEqual(response.data["status"], "active")

    def test_create_session_with_own_playlist(self):
        response = self.host_client.post(self.create_session_url, {"playlist_id": self.host_playlist.id}, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_create_session_with_others_playlist_forbidden(self):
        response = self.host_client.post(self.create_session_url, {"playlist_id": self.stranger_playlist.id}, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_detail_session_access(self):
        # Create session
        response = self.host_client.post(self.create_session_url, format='json')
        session_id = response.data["id"]
        invite_code = response.data["invite_code"]
        detail_url = reverse('connect_session_detail', kwargs={'pk': session_id})

        # Host can access
        self.assertEqual(self.host_client.get(detail_url).status_code, status.HTTP_200_OK)

        # Stranger cannot access
        self.assertEqual(self.stranger_client.get(detail_url).status_code, status.HTTP_404_NOT_FOUND)

        # Guest joins
        self.guest_client.post(reverse('connect_session_join'), {"invite_code": invite_code}, format='json')

        # Guest can now access
        self.assertEqual(self.guest_client.get(detail_url).status_code, status.HTTP_200_OK)

    def test_leave_session_enumeration(self):
        response = self.host_client.post(self.create_session_url, format='json')
        session_id = response.data["id"]
        leave_url = reverse('connect_session_leave', kwargs={'pk': session_id})

        # Stranger tries to leave (enumeration test)
        self.assertEqual(self.stranger_client.post(leave_url).status_code, status.HTTP_404_NOT_FOUND)

        # Host leaves
        self.assertEqual(self.host_client.post(leave_url).status_code, status.HTTP_200_OK)


class ConnectWebSocketTestCase(TestCase):
    def setUp(self):
        self.host_user = User.objects.create_user(username="hostws", email="hws@test.com", password="pwd")
        self.guest_user = User.objects.create_user(username="guestws", email="gws@test.com", password="pwd")
        self.stranger_user = User.objects.create_user(username="strangerws", email="sws@test.com", password="pwd")
        
        self.session = ConnectSession.objects.create(host_user=self.host_user, status='active')
        ConnectParticipant.objects.create(session=self.session, user=self.host_user)
        ConnectParticipant.objects.create(session=self.session, user=self.guest_user)
        
        self.host_token = str(AccessToken.for_user(self.host_user))
        self.guest_token = str(AccessToken.for_user(self.guest_user))
        self.stranger_token = str(AccessToken.for_user(self.stranger_user))

    async def test_ws_unauthenticated_rejected(self):
        communicator = WebsocketCommunicator(application, f"/ws/connect/{self.session.id}/")
        connected, subprotocol = await communicator.connect()
        self.assertFalse(connected)
        await communicator.disconnect()

    async def test_ws_stranger_rejected(self):
        communicator = WebsocketCommunicator(application, f"/ws/connect/{self.session.id}/?token={self.stranger_token}")
        connected, subprotocol = await communicator.connect()
        self.assertFalse(connected) # Code 4003 should reject connection
        await communicator.disconnect()

    async def test_ws_host_and_guest_accepted(self):
        host_comm = WebsocketCommunicator(application, f"/ws/connect/{self.session.id}/?token={self.host_token}")
        connected, _ = await host_comm.connect()
        self.assertTrue(connected)
        
        guest_comm = WebsocketCommunicator(application, f"/ws/connect/{self.session.id}/?token={self.guest_token}")
        connected2, _ = await guest_comm.connect()
        self.assertTrue(connected2)

        await host_comm.disconnect()
        await guest_comm.disconnect()

    async def test_ws_host_permissions(self):
        host_comm = WebsocketCommunicator(application, f"/ws/connect/{self.session.id}/?token={self.host_token}")
        await host_comm.connect()
        # Drop the initial joined event
        await host_comm.receive_json_from()

        await host_comm.send_json_to({"event": "play", "position": 10})
        response = await host_comm.receive_json_from()
        self.assertEqual(response["event"], "play")
        self.assertEqual(response["position"], 10)
        
        await host_comm.disconnect()

    async def test_ws_guest_permissions_denied(self):
        guest_comm = WebsocketCommunicator(application, f"/ws/connect/{self.session.id}/?token={self.guest_token}")
        await guest_comm.connect()
        await guest_comm.receive_json_from()

        # Guest trying to play -> unauthorized
        await guest_comm.send_json_to({"event": "play", "position": 10})
        response = await guest_comm.receive_json_from()
        self.assertIn("error", response)
        
        await guest_comm.disconnect()

    async def test_ws_invalid_payload(self):
        host_comm = WebsocketCommunicator(application, f"/ws/connect/{self.session.id}/?token={self.host_token}")
        await host_comm.connect()
        await host_comm.receive_json_from()

        # Invalid track id length
        await host_comm.send_json_to({"event": "track_changed", "track_id": "A" * 100})
        response = await host_comm.receive_json_from()
        self.assertIn("error", response)

        # Invalid position type
        await host_comm.send_json_to({"event": "seek", "position": "INVALID"})
        response2 = await host_comm.receive_json_from()
        # Should fallback to 0 instead of crashing or returning error, according to our implementation
        if "error" not in response2:
            self.assertEqual(response2["position"], 0)

        await host_comm.disconnect()

