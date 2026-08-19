from rest_framework import status, permissions, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.throttling import ScopedRateThrottle
from django.core.mail import send_mail
from django.contrib.auth import get_user_model
from django.utils.crypto import get_random_string
from django.core.cache import cache
import requests
from .serializers import (
    RegisterSerializer, LoginSerializer, UserSerializer,
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
                token = get_random_string(length=32)
                # Store token in cache for 15 minutes (900 seconds)
                cache.set(f"pwd_reset_{token}", user.id, timeout=900)
                
                reset_link = f"sonoritiz://reset-password?token={token}"
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
        
        user_id = cache.get(f"pwd_reset_{token}")
        if not user_id:
            return Response({"error": {"code": "INVALID_TOKEN", "message": "Ce lien a expiré ou est invalide."}}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = User.objects.get(id=user_id)
            user.set_password(new_password)
            user.save()
            cache.delete(f"pwd_reset_{token}")
            return Response({"detail": "Mot de passe mis à jour avec succès."}, status=status.HTTP_200_OK)
        except User.DoesNotExist:
            return Response({"error": {"code": "USER_NOT_FOUND", "message": "Utilisateur introuvable."}}, status=status.HTTP_404_NOT_FOUND)

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
        google_response = requests.get(f"https://oauth2.googleapis.com/tokeninfo?id_token={id_token}")
        if google_response.status_code != 200:
            return Response({"error": {"code": "INVALID_GOOGLE_TOKEN", "message": "Token Google invalide."}}, status=status.HTTP_400_BAD_REQUEST)
            
        user_data = google_response.json()
        email = user_data.get('email')
        
        if not email:
            return Response({"error": {"code": "NO_EMAIL", "message": "Email manquant dans le profil Google."}}, status=status.HTTP_400_BAD_REQUEST)
            
        # Get or create user
        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            username = email.split('@')[0]
            # Ensure unique username
            base_username = username
            counter = 1
            while User.objects.filter(username__iexact=username).exists():
                username = f"{base_username}{counter}"
                counter += 1
            user = User.objects.create_user(email=email, username=username, password=get_random_string(32))
            
        refresh = RefreshToken.for_user(user)
        return Response({
            "user": UserSerializer(user).data,
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

