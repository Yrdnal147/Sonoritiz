from django.conf import settings
from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient # pyright: ignore[reportMissingImports]
from rest_framework import status # type: ignore

User = get_user_model()

class AuthEndpointsTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.register_url = reverse('auth_register')
        self.login_url = reverse('auth_login')
        self.profile_url = reverse('auth_profile')
        self.user_data = {
            "email": "testuser@sonoritiz.com",
            "username": "testuser",
            "password": "Password123!"
        }

    def test_register_success(self):
        response = self.client.post(self.register_url, self.user_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn("tokens", response.data)
        self.assertIn("access", response.data["tokens"])
        self.assertIn("user", response.data)
        self.assertEqual(response.data["user"]["email"], "testuser@sonoritiz.com")

    def test_register_duplicate_email(self):
        self.client.post(self.register_url, self.user_data, format='json')
        response = self.client.post(self.register_url, self.user_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["error"]["code"], "BAD_REQUEST")

    def test_login_success(self):
        User.objects.create_user(**self.user_data)
        login_payload = {
            "email": "testuser@sonoritiz.com",
            "password": "Password123!"
        }
        response = self.client.post(self.login_url, login_payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("tokens", response.data)

    def test_login_invalid_credentials(self):
        login_payload = {
            "email": "wrong@sonoritiz.com",
            "password": "WrongPassword"
        }
        response = self.client.post(self.login_url, login_payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["error"]["code"], "BAD_REQUEST")
        self.assertEqual(response.data["error"]["message"], "Identifiants invalides.")

    def test_google_web_client_id_configured_by_default(self):
        self.assertTrue(bool(settings.GOOGLE_WEB_CLIENT_ID))
        self.assertIn(".apps.googleusercontent.com", settings.GOOGLE_WEB_CLIENT_ID)

    def test_favorite_artists_isolated_per_user(self):
        user_a = User.objects.create_user(
            email="a@sonoritiz.com", username="user_a", password="Password123!"
        )
        user_b = User.objects.create_user(
            email="b@sonoritiz.com", username="user_b", password="Password123!"
        )
        prefs_url = reverse('auth_preferences')

        self.client.force_authenticate(user=user_a)
        res_patch = self.client.patch(
            prefs_url,
            {"favorite_artists": ["Édith Piaf", "Charles Aznavour", "édith piaf", "Mozart"]},
            format='json',
        )
        self.assertEqual(res_patch.status_code, status.HTTP_200_OK)
        self.assertEqual(
            res_patch.data["favorite_artists"],
            ["Édith Piaf", "Charles Aznavour", "Mozart"],
        )

        # User B ne doit jamais recevoir les artistes de User A
        self.client.force_authenticate(user=user_b)
        res_b = self.client.get(prefs_url)
        self.assertEqual(res_b.status_code, status.HTTP_200_OK)
        self.assertEqual(res_b.data["favorite_artists"], [])

        # Reconnexion sur User A : données intactes
        self.client.force_authenticate(user=user_a)
        res_a = self.client.get(prefs_url)
        self.assertEqual(res_a.status_code, status.HTTP_200_OK)
        self.assertEqual(
            res_a.data["favorite_artists"],
            ["Édith Piaf", "Charles Aznavour", "Mozart"],
        )
