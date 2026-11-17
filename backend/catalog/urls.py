from django.urls import path
from .views import (
    TrendingTracksView,
    SearchTracksView,
    TrackDetailView,
    GenresView,
    TrackLyricsView,
    DeezerProxyView,
)

urlpatterns = [
    path('trending/', TrendingTracksView.as_view(), name='tracks_trending'),
    path('search/', SearchTracksView.as_view(), name='tracks_search'),
    path('deezer-proxy/', DeezerProxyView.as_view(), name='deezer_proxy'),
    path('<str:track_id>/', TrackDetailView.as_view(), name='track_detail'),
    path('<str:track_id>/lyrics/', TrackLyricsView.as_view(), name='track_lyrics'),
]
