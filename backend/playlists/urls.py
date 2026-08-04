from django.urls import path
from .views import (
    PlaylistsListCreateView,
    PlaylistDetailView,
    PlaylistTracksAddView,
    PlaylistTrackDeleteView
)

urlpatterns = [
    path('', PlaylistsListCreateView.as_view(), name='playlists_list_create'),
    path('<int:pk>/', PlaylistDetailView.as_view(), name='playlist_detail'),
    path('<int:pk>/tracks/', PlaylistTracksAddView.as_view(), name='playlist_tracks_add'),
    path('<int:pk>/tracks/<str:track_id>/', PlaylistTrackDeleteView.as_view(), name='playlist_track_delete'),
]
