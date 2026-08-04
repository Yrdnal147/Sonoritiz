from django.urls import path
from .views import HistoryListCreateView

urlpatterns = [
    path('', HistoryListCreateView.as_view(), name='history_list_create'),
]
