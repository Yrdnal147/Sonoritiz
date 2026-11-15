from rest_framework import serializers
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            'id',
            'email',
            'username',
            'favorite_artists',
            'superliked_tracks',
            'favorite_albums',
            'created_at',
        )
        read_only_fields = ('id', 'created_at')


class UserPreferencesSerializer(serializers.Serializer):
    favorite_artists = serializers.ListField(
        child=serializers.CharField(max_length=120, trim_whitespace=True),
        max_length=50,
        required=False,
    )
    superliked_tracks = serializers.ListField(
        child=serializers.DictField(),
        max_length=50,
        required=False,
    )
    favorite_albums = serializers.ListField(
        child=serializers.DictField(),
        max_length=200,
        required=False,
    )

    def validate_favorite_artists(self, value):
        cleaned = []
        seen = set()
        for item in value:
            name = item.strip()
            if not name:
                continue
            key = name.lower()
            if key not in seen:
                seen.add(key)
                cleaned.append(name)
        return cleaned

    def validate_superliked_tracks(self, value):
        cleaned = []
        seen = set()
        for item in value:
            if not isinstance(item, dict):
                continue
            track_id = str(item.get('id') or item.get('youtube_id') or '').strip()
            if not track_id or track_id in seen:
                continue
            seen.add(track_id)
            normalized = dict(item)
            normalized['id'] = track_id
            cleaned.append(normalized)
            if len(cleaned) >= 20:
                break
        return cleaned

    def validate_favorite_albums(self, value):
        cleaned = []
        seen = set()
        for item in value:
            if not isinstance(item, dict):
                continue
            clean_id = str(item.get('id') or '').strip()
            title = str(item.get('title') or '').strip()
            artist_name = str(item.get('artist_name') or item.get('artistName') or '').strip()
            if not clean_id and not title:
                continue
            if clean_id and clean_id != '0':
                identity = f'id:{clean_id}'
            else:
                identity = f'meta:{title.lower()}__{artist_name.lower()}'
            if identity in seen:
                continue
            seen.add(identity)
            cleaned.append(dict(item))
            if len(cleaned) >= 150:
                break
        return cleaned

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ('id', 'email', 'username', 'password')

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Un utilisateur avec cet e-mail existe déjà.")
        return value.lower()

    def create(self, validated_data):
        user = User.objects.create_user(
            email=validated_data['email'],
            username=validated_data['username'],
            password=validated_data['password']
        )
        return user

class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        email = attrs.get('email', '').lower()
        password = attrs.get('password', '')

        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            raise serializers.ValidationError({"detail": "Identifiants invalides."})

        if not user.check_password(password):
            raise serializers.ValidationError({"detail": "Identifiants invalides."})

        if not user.is_active:
            raise serializers.ValidationError({"detail": "Ce compte est désactivé."})

        attrs['user'] = user
        return attrs

class PasswordResetSerializer(serializers.Serializer):
    email = serializers.EmailField()

class PasswordResetConfirmSerializer(serializers.Serializer):
    token = serializers.CharField()
    new_password = serializers.CharField(min_length=8)

class GoogleLoginSerializer(serializers.Serializer):
    id_token = serializers.CharField()
