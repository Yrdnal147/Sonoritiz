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
