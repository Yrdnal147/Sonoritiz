import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from .models import ConnectSession, ConnectParticipant

class ConnectConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.session_id = self.scope['url_route']['kwargs']['session_id']
        self.room_group_name = f"connect_{self.session_id}"
        self.user = self.scope.get('user')

        if not self.user or self.user.is_anonymous:
            await self.close(code=4001)
            return

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
                    'email': self.user.email,
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

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        event_type = data.get('event')
        if not event_type:
            return

        payload = {
            'type': 'connect_event',
            'event': event_type,
            'sender_id': self.user.id if self.user else None,
        }

        if event_type == 'play':
            payload['position'] = data.get('position', 0)
        elif event_type == 'pause':
            payload['position'] = data.get('position', 0)
        elif event_type == 'seek':
            payload['position'] = data.get('position', 0)
        elif event_type == 'track_changed':
            track_id = data.get('track_id')
            payload['track_id'] = track_id
            if track_id:
                await self.update_session_track(track_id)
        elif event_type == 'sync_state':
            payload['position'] = data.get('position', 0)
            payload['is_playing'] = data.get('is_playing', False)

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
            session = ConnectSession.objects.get(pk=self.session_id)
            session.current_jamendo_track_id = str(track_id)
            session.save()
        except ConnectSession.DoesNotExist:
            pass
