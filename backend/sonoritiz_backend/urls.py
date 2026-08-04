from django.contrib import admin
from django.urls import path, include
from catalog.views import GenresView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('accounts.urls')),
    path('api/tracks/', include('catalog.urls')),
    path('api/genres/', GenresView.as_view(), name='genres_list'),
    path('api/favorites/', include('favorites.urls')),
    path('api/playlists/', include('playlists.urls')),
    path('api/history/', include('history.urls')),
    path('api/connect/', include('connect.urls')),
]



