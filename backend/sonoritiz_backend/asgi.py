import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from connect.middleware import JwtAuthMiddleware
import connect.routing

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sonoritiz_backend.settings')

django_asgi_app = get_asgi_application()

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": JwtAuthMiddleware(
        URLRouter(
            connect.routing.websocket_urlpatterns
        )
    ),
})

