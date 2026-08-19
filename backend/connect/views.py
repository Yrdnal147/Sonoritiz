from rest_framework import status, permissions, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import ConnectSession, ConnectParticipant
from .serializers import ConnectSessionSerializer, ConnectJoinSerializer
from playlists.models import Playlist
from django.db.models import Q

class ConnectSessionCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        playlist_id = request.data.get('playlist_id')

        if playlist_id:
            try:
                playlist = Playlist.objects.get(pk=playlist_id, user=request.user)
            except Playlist.DoesNotExist:
                return Response(
                    {"error": {"code": "FORBIDDEN", "message": "Cette playlist ne vous appartient pas ou est introuvable."}},
                    status=status.HTTP_403_FORBIDDEN
                )
        else:
            playlist = None

        session = ConnectSession.objects.create(
            host_user=request.user,
            status='active',
            playlist=playlist
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

        # Remove the session.status = 'active' override here so the host's state is preserved.
        return Response(ConnectSessionSerializer(session).data, status=status.HTTP_200_OK)

class ConnectSessionDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        try:
            # Enforce that only host or active participant can view the session
            session = ConnectSession.objects.filter(
                Q(host_user=request.user) | Q(participants__user=request.user),
                pk=pk
            ).distinct().get()
            return Response(ConnectSessionSerializer(session).data, status=status.HTTP_200_OK)
        except ConnectSession.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Session introuvable ou accès refusé."}},
                status=status.HTTP_404_NOT_FOUND
            )

class ConnectSessionLeaveView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            # Must verify participation to avoid enumeration
            session = ConnectSession.objects.filter(
                Q(host_user=request.user) | Q(participants__user=request.user),
                pk=pk
            ).distinct().get()
        except ConnectSession.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Session introuvable ou vous n'y participez pas."}},
                status=status.HTTP_404_NOT_FOUND
            )

        ConnectParticipant.objects.filter(session=session, user=request.user).delete()

        # If host leaves or no participants left, close the session
        if session.host_user == request.user or session.participants.count() == 0:
            session.status = 'ended'
            session.save()

        return Response({"message": "Vous avez quitté la session."}, status=status.HTTP_200_OK)
