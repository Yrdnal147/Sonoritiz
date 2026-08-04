from django.urls import path
from .views import FavoritesListCreateView, FavoriteDetailView

urlpatterns = [
    path('', FavoritesListCreateView.as_view(), name='favorites_list_create'),
    path('<str:pk>/', FavoriteDetailView.as_view(), name='favorite_detail'),
]
