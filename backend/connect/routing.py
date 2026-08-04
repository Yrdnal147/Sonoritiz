from django.urls import re_path
from .consumers import ConnectConsumer

websocket_urlpatterns = [
    re_path(r'^ws/connect/(?P<session_id>\w+)/$', ConnectConsumer.as_asgi()),
]
