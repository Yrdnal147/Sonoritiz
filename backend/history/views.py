from rest_framework import status, permissions, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.pagination import LimitOffsetPagination
from .models import ListeningHistory
from .serializers import ListeningHistorySerializer, ListeningHistoryCreateSerializer

class HistoryPagination(LimitOffsetPagination):
    default_limit = 20
    max_limit = 50

class HistoryListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        history = ListeningHistory.objects.filter(user=request.user)
        paginator = HistoryPagination()
        paginated_history = paginator.paginate_queryset(history, request, view=self)
        serializer = ListeningHistorySerializer(paginated_history, many=True)
        return paginator.get_paginated_response(serializer.data)

    def post(self, request):
        serializer = ListeningHistoryCreateSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)

        history_item = serializer.save(user=request.user)
        return Response(ListeningHistorySerializer(history_item).data, status=status.HTTP_201_CREATED)
