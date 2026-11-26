from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import AuthenticationFailed, InvalidToken
from rest_framework_simplejwt.settings import api_settings


class LightweightJWTAuthentication(JWTAuthentication):
    """
    Authentification JWT optimisée pour Supabase PostgreSQL :
    Diffère systématiquement le chargement des 3 colonnes JSON volumineuses
    (`favorite_artists`, `superliked_tracks`, `favorite_albums`) de `accounts_user`
    sur toutes les requêtes API ordinaires (Connect, Favoris, Playlists, Historique).
    Django ne les chargera à la demande que sur `/auth/profile/` et `/auth/preferences/`.
    """

    def get_user(self, validated_token):
        try:
            user_id = validated_token[api_settings.USER_ID_CLAIM]
        except KeyError:
            raise InvalidToken("Le jeton ne contient aucun identifiant utilisateur valide.")

        try:
            user = (
                self.user_model.objects.defer(
                    'favorite_artists',
                    'superliked_tracks',
                    'favorite_albums',
                ).get(**{api_settings.USER_ID_FIELD: user_id})
            )
        except self.user_model.DoesNotExist:
            raise AuthenticationFailed("Utilisateur introuvable.", code="user_not_found")

        if not user.is_active:
            raise AuthenticationFailed("Ce compte est désactivé.", code="user_inactive")

        return user
