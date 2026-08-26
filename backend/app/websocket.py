from fastapi import WebSocket
from typing import Dict, List
import json
from uuid import UUID

class ConnectionManager:
    def __init__(self):
        # Maps restaurant_id (tenant ID) to its list of active WebSockets
        self.active_connections: Dict[UUID, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, restaurant_id: UUID):
        await websocket.accept()
        if restaurant_id not in self.active_connections:
            self.active_connections[restaurant_id] = []
        self.active_connections[restaurant_id].append(websocket)

    def disconnect(self, websocket: WebSocket, restaurant_id: UUID):
        if restaurant_id in self.active_connections:
            if websocket in self.active_connections[restaurant_id]:
                self.active_connections[restaurant_id].remove(websocket)
            if not self.active_connections[restaurant_id]:
                del self.active_connections[restaurant_id]

    async def send_personal_message(self, message: dict, websocket: WebSocket):
        await websocket.send_text(json.dumps(message))

    async def broadcast_to_tenant(self, restaurant_id: UUID, message: dict):
        if restaurant_id in self.active_connections:
            message_str = json.dumps(message)
            for connection in self.active_connections[restaurant_id]:
                try:
                    await connection.send_text(message_str)
                except Exception:
                    # Connection might have died, we'll clean it up during disconnect
                    pass

manager = ConnectionManager()
