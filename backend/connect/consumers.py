import json
import time
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.db.models import Q
from .models import ConnectSession, ConnectParticipant

class ConnectConsumer(AsyncWebsocketConsumer):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.last_message_times = []
        self.RATE_LIMIT_MESSAGES = 10
        self.RATE_LIMIT_WINDOW = 1.0  # seconds

    @database_sync_to_async
    def verify_participation_and_get_session(self):
        try:
            # Check if session exists and user is host or participant
            session = ConnectSession.objects.filter(
                Q(host_user=self.user) | Q(participants__user=self.user),
                pk=self.session_id
            ).distinct().get()
            return True, session.host_user_id
        except ConnectSession.DoesNotExist:
            return False, None

    async def connect(self):
        self.session_id = self.scope['url_route']['kwargs']['session_id']
        self.room_group_name = f"connect_{self.session_id}"
        self.user = self.scope.get('user')

        if not self.user or self.user.is_anonymous:
            await self.close(code=4001)
            return

        is_authorized, host_id = await self.verify_participation_and_get_session()
        if not is_authorized:
            # Code 4003: Forbidden
            await self.close(code=4003)
            return
            
        self.is_host = (self.user.id == host_id)

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        await self.accept()

        # Notify others that participant joined
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'connect_event',
                'event': 'participant_joined',
                'user': {
                    'id': self.user.id,
                    'username': self.user.username,
                    # Removed email to prevent PII leak
                }
            }
        )

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            # Notify others that participant left
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'connect_event',
                    'event': 'participant_left',
                    'user': {
                        'id': self.user.id if self.user and not self.user.is_anonymous else None,
                        'username': self.user.username if self.user and not self.user.is_anonymous else 'Inconnu',
                    }
                }
            )

            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )

    def _check_rate_limit(self):
        now = time.time()
        # Keep only timestamps within the window
        self.last_message_times = [t for t in self.last_message_times if now - t < self.RATE_LIMIT_WINDOW]
        if len(self.last_message_times) >= self.RATE_LIMIT_MESSAGES:
            return False
        self.last_message_times.append(now)
        return True

    async def receive(self, text_data):
        if not self._check_rate_limit():
            # Drop the message if rate limit exceeded (prevent spam)
            return

        # Payload size validation (max 4KB to prevent excessive memory usage)
        if len(text_data) > 4096:
            return

        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        if not isinstance(data, dict):
            return

        event_type = data.get('event')
        if not isinstance(event_type, str):
            return

        # Privileged events (only host)
        privileged_events = ['play', 'pause', 'seek', 'sync_state', 'track_changed']
        if event_type in privileged_events and not self.is_host:
            # Unauthorized action by participant, silently drop or send error
            await self.send(text_data=json.dumps({"error": "Unauthorized action. Only host can send this event."}))
            return

        payload = {
            'type': 'connect_event',
            'event': event_type,
            'sender_id': self.user.id if self.user else None,
        }

        # Validate types and values
        if event_type in ['play', 'pause', 'seek', 'sync_state']:
            position = data.get('position', 0)
            # Accept int or float, otherwise default to 0
            if not isinstance(position, (int, float)):
                position = 0
            payload['position'] = position
            
            if event_type == 'sync_state':
                is_playing = data.get('is_playing', False)
                payload['is_playing'] = bool(is_playing)

        elif event_type == 'track_changed':
            track_id = data.get('track_id')
            if not isinstance(track_id, str) or len(track_id) > 64:
                await self.send(text_data=json.dumps({"error": "Invalid track_id"}))
                return
                
            payload['track_id'] = track_id
            await self.update_session_track(track_id)
            
        else:
            # General custom events, pass through minimal validation
            pass

        # Broadcast event to group
        await self.channel_layer.group_send(
            self.room_group_name,
            payload
        )

    async def connect_event(self, event):
        """Handler for events sent from channel layer to client."""
        await self.send(text_data=json.dumps(event))

    @database_sync_to_async
    def update_session_track(self, track_id):
        try:
            session = ConnectSession.objects.get(pk=self.session_id, host_user=self.user)
            session.current_jamendo_track_id = str(track_id)
            session.save(update_fields=['current_jamendo_track_id'])
        except ConnectSession.DoesNotExist:
            pass
