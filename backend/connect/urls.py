from django.urls import path
from .views import (
    ConnectSessionCreateView,
    ConnectSessionJoinView,
    ConnectSessionDetailView,
    ConnectSessionLeaveView
)

urlpatterns = [
    path('sessions/', ConnectSessionCreateView.as_view(), name='connect_session_create'),
    path('sessions/join/', ConnectSessionJoinView.as_view(), name='connect_session_join'),
    path('sessions/<int:pk>/', ConnectSessionDetailView.as_view(), name='connect_session_detail'),
    path('sessions/<int:pk>/leave/', ConnectSessionLeaveView.as_view(), name='connect_session_leave'),
]
