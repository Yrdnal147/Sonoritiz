from rest_framework import status, permissions, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.throttling import ScopedRateThrottle
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.contrib.auth import get_user_model
from django.conf import settings
from django.core.exceptions import ValidationError as DjangoValidationError
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from django.utils.crypto import get_random_string
import requests
from .serializers import (
    RegisterSerializer, LoginSerializer, UserSerializer,
    UserPreferencesSerializer,
    PasswordResetSerializer, PasswordResetConfirmSerializer,
    GoogleLoginSerializer
)

User = get_user_model()

class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth'

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        return Response({
            "user": UserSerializer(user).data,
            "tokens": {
                "refresh": str(refresh),
                "access": str(refresh.access_token),
            }
        }, status=status.HTTP_201_CREATED)

class LoginView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth'

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)
        user = serializer.validated_data['user']
        refresh = RefreshToken.for_user(user)
        return Response({
            "user": UserSerializer(user).data,
            "tokens": {
                "refresh": str(refresh),
                "access": str(refresh.access_token),
            }
        }, status=status.HTTP_200_OK)

class PasswordResetView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth'

    def post(self, request):
        serializer = PasswordResetSerializer(data=request.data)
        if serializer.is_valid():
            email = serializer.validated_data['email'].lower()
            try:
                user = User.objects.get(email__iexact=email)
                uid = urlsafe_base64_encode(force_bytes(user.pk))
                token = default_token_generator.make_token(user)
                reset_link = f"sonoritiz:///reset-password?token={uid}.{token}"
                send_mail(
                    "Réinitialisation de votre mot de passe Sonoritiz",
                    f"Cliquez sur ce lien depuis votre téléphone pour réinitialiser votre mot de passe : {reset_link}\nCe lien expire dans 15 minutes.",
                    "no-reply@sonoritiz.com",
                    [email],
                    fail_silently=False,
                )
            except User.DoesNotExist:
                pass # Prevent email enumeration
            
        return Response({"detail": "Si cet e-mail existe, un lien de réinitialisation a été envoyé."}, status=status.HTTP_200_OK)

class PasswordResetConfirmView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth'

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)
        
        token = serializer.validated_data['token']
        new_password = serializer.validated_data['new_password']

        try:
            uid, reset_token = token.split('.', 1)
            user_id = force_str(urlsafe_base64_decode(uid))
            user = User.objects.get(pk=user_id)
            if not default_token_generator.check_token(user, reset_token):
                raise ValueError('Expired or invalid reset token')
            validate_password(new_password, user)
        except User.DoesNotExist:
            return Response({"error": {"code": "INVALID_TOKEN", "message": "Ce lien a expiré ou est invalide."}}, status=status.HTTP_400_BAD_REQUEST)
        except (ValueError, TypeError, DjangoValidationError) as error:
            if isinstance(error, DjangoValidationError):
                raise serializers.ValidationError({'new_password': error.messages})
            return Response({"error": {"code": "INVALID_TOKEN", "message": "Ce lien a expiré ou est invalide."}}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(new_password)
        user.save()
        return Response({"detail": "Mot de passe mis à jour avec succès."}, status=status.HTTP_200_OK)

class GoogleLoginView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth'

    def post(self, request):
        serializer = GoogleLoginSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)
        
        id_token = serializer.validated_data['id_token']
        
        # Verify token with Google
        try:
            google_response = requests.get(
                'https://oauth2.googleapis.com/tokeninfo',
                params={'id_token': id_token},
                timeout=10,
            )
        except requests.RequestException:
            return Response(
                {"error": {"code": "GOOGLE_VERIFICATION_UNAVAILABLE", "message": "La vérification Google est temporairement indisponible."}},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        if google_response.status_code != 200:
            return Response({"error": {"code": "INVALID_GOOGLE_TOKEN", "message": "Token Google invalide."}}, status=status.HTTP_400_BAD_REQUEST)
            
        user_data = google_response.json()
        if not settings.GOOGLE_WEB_CLIENT_ID or user_data.get('aud') != settings.GOOGLE_WEB_CLIENT_ID:
            return Response({"error": {"code": "INVALID_GOOGLE_AUDIENCE", "message": "Token Google destiné à une autre application."}}, status=status.HTTP_400_BAD_REQUEST)

        if str(user_data.get('email_verified', '')).lower() != 'true':
            return Response({"error": {"code": "UNVERIFIED_GOOGLE_EMAIL", "message": "L'adresse Google n'est pas vérifiée."}}, status=status.HTTP_400_BAD_REQUEST)

        email = user_data.get('email')
        
        if not email:
            return Response({"error": {"code": "NO_EMAIL", "message": "Email manquant dans le profil Google."}}, status=status.HTTP_400_BAD_REQUEST)
            
        # Get or create user
        is_new_user = False
        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            is_new_user = True
            username = email.split('@')[0]
            # Ensure unique username
            base_username = username
            counter = 1
            while User.objects.filter(username__iexact=username).exists():
                username = f"{base_username}{counter}"
                counter += 1
            user = User.objects.create_user(email=email.lower(), username=username, password=get_random_string(32))
            
        refresh = RefreshToken.for_user(user)
        return Response({
            "user": UserSerializer(user).data,
            "is_new_user": is_new_user,
            "tokens": {
                "refresh": str(refresh),
                "access": str(refresh.access_token),
            }
        }, status=status.HTTP_200_OK)

class ProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)


class UserPreferencesView(APIView):
    """Lit ou met à jour les préférences (artistes, superlikes, albums favoris) de l'utilisateur connecté."""
    permission_classes = [permissions.IsAuthenticated]

    def _build_preferences_payload(self, user):
        return {
            "favorite_artists": user.favorite_artists if isinstance(user.favorite_artists, list) else [],
            "superliked_tracks": user.superliked_tracks if isinstance(user.superliked_tracks, list) else [],
            "favorite_albums": user.favorite_albums if isinstance(user.favorite_albums, list) else [],
        }

    def get(self, request):
        return Response(self._build_preferences_payload(request.user), status=status.HTTP_200_OK)

    def _update_preferences(self, request):
        serializer = UserPreferencesSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)

        update_fields = []
        for field_name in ('favorite_artists', 'superliked_tracks', 'favorite_albums'):
            if field_name in serializer.validated_data:
                setattr(request.user, field_name, serializer.validated_data[field_name])
                update_fields.append(field_name)

        if update_fields:
            update_fields.append('updated_at')
            request.user.save(update_fields=update_fields)

        return Response(
            self._build_preferences_payload(request.user),
            status=status.HTTP_200_OK,
        )

    def put(self, request):
        return self._update_preferences(request)

    def patch(self, request):
        return self._update_preferences(request)

