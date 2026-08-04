from rest_framework import status, permissions, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import ConnectSession, ConnectParticipant
from .serializers import ConnectSessionSerializer, ConnectJoinSerializer

class ConnectSessionCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        playlist_id = request.data.get('playlist_id')

        session = ConnectSession.objects.create(
            host_user=request.user,
            status='active',
            playlist_id=playlist_id if playlist_id else None
        )

        ConnectParticipant.objects.create(
            session=session,
            user=request.user
        )

        return Response(ConnectSessionSerializer(session).data, status=status.HTTP_201_CREATED)

class ConnectSessionJoinView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = ConnectJoinSerializer(data=request.data)
        if not serializer.is_valid():
            raise serializers.ValidationError(serializer.errors)

        invite_code = serializer.validated_data['invite_code'].upper().strip()

        try:
            session = ConnectSession.objects.get(invite_code=invite_code)
        except ConnectSession.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Code d'invitation invalide."}},
                status=status.HTTP_404_NOT_FOUND
            )

        if session.status == 'ended':
            return Response(
                {"error": {"code": "BAD_REQUEST", "message": "Cette session est terminée."}},
                status=status.HTTP_400_BAD_REQUEST
            )

        ConnectParticipant.objects.get_or_create(
            session=session,
            user=request.user
        )

        session.status = 'active'
        session.save()

        return Response(ConnectSessionSerializer(session).data, status=status.HTTP_200_OK)

class ConnectSessionDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        try:
            session = ConnectSession.objects.get(pk=pk)
            return Response(ConnectSessionSerializer(session).data, status=status.HTTP_200_OK)
        except ConnectSession.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Session introuvable."}},
                status=status.HTTP_404_NOT_FOUND
            )

class ConnectSessionLeaveView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            session = ConnectSession.objects.get(pk=pk)
        except ConnectSession.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Session introuvable."}},
                status=status.HTTP_404_NOT_FOUND
            )

        ConnectParticipant.objects.filter(session=session, user=request.user).delete()

        # If host leaves or no participants left, close the session
        if session.host_user == request.user or session.participants.count() == 0:
            session.status = 'ended'
            session.save()

        return Response({"message": "Vous avez quitté la session."}, status=status.HTTP_200_OK)
