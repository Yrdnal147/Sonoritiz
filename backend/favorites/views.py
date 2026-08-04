from rest_framework import status, permissions, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.pagination import LimitOffsetPagination
from .models import Favorite
from catalog.models import TrackCache
from .serializers import FavoriteSerializer, FavoriteCreateSerializer

class FavoritesPagination(LimitOffsetPagination):
    default_limit = 20
    max_limit = 50

class FavoritesListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        favorites = Favorite.objects.filter(user=request.user)
        paginator = FavoritesPagination()
        paginated_favorites = paginator.paginate_queryset(favorites, request, view=self)
        serializer = FavoriteSerializer(paginated_favorites, many=True)
        return paginator.get_paginated_response(serializer.data)

    def post(self, request):
        serializer = FavoriteCreateSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)

        youtube_id = serializer.validated_data['youtube_id']

        # Cache track metadata in TrackCache if title is provided
        title = serializer.validated_data.get('title', '')
        if title:
            TrackCache.objects.update_or_create(
                youtube_id=youtube_id,
                defaults={
                    'title': title,
                    'artist_name': serializer.validated_data.get('artist_name', ''),
                    'album_name': serializer.validated_data.get('album_name', ''),
                    'cover_url': serializer.validated_data.get('cover_url', ''),
                    'duration_seconds': serializer.validated_data.get('duration_seconds', 0),
                    'audio_url': '',
                    'genre': '',
                    'license_ccurl': '',
                }
            )

        favorite, created = Favorite.objects.get_or_create(
            user=request.user,
            youtube_id=youtube_id
        )

        return Response(FavoriteSerializer(favorite).data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

class FavoriteDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, pk):
        try:
            # Try by PK or by youtube_id
            try:
                # Try by Favorite ID first
                favorite = Favorite.objects.get(user=request.user, pk=int(pk) if pk.isdigit() else 0)
            except Favorite.DoesNotExist:
                # Fallback to YouTube ID
                favorite = Favorite.objects.get(user=request.user, youtube_id=pk)

            favorite.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Favorite.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Favori introuvable."}},
                status=status.HTTP_404_NOT_FOUND
            )
