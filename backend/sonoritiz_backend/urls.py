from django.contrib import admin
from django.db import connection
from django.http import JsonResponse
from django.urls import path, include
from catalog.views import GenresView


def health_keepalive_view(request):
    """Endpoint anti-veille (Cron Vercel quotidien) qui maintient la base Supabase active."""
    db_ok = False
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        db_ok = True
    except Exception:
        db_ok = False
    return JsonResponse({"status": "ok", "database": "connected" if db_ok else "unreachable"})


urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/health/', health_keepalive_view, name='api_health_keepalive'),
    path('api/auth/', include('accounts.urls')),
    path('api/tracks/', include('catalog.urls')),
    path('api/genres/', GenresView.as_view(), name='genres_list'),
    path('api/favorites/', include('favorites.urls')),
    path('api/playlists/', include('playlists.urls')),
    path('api/history/', include('history.urls')),
    path('api/connect/', include('connect.urls')),
]



