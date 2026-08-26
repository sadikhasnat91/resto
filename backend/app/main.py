from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query, status, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from uuid import UUID
from .database import engine, Base, get_db
from .seed import seed
from .websocket import manager
from .auth_utils import decode_token
from .routers import auth, onboarding, dashboard, menu, tables, orders, inventory, expenses, admin, branches, reports
from . import schemas, dependencies, models

# Create DB tables
Base.metadata.create_all(bind=engine)

# Run Seed Data
try:
    seed()
    print("Database seeding completed.")
except Exception as e:
    print(f"Error seeding database: {e}")

app = FastAPI(
    title="RestroFlow API",
    description="Multi-tenant Restaurant Management SaaS API",
    version="1.0.0"
)

# Configure CORS for Flutter Web / desktop
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production, restrict this to specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(onboarding.router)
app.include_router(dashboard.router)
app.include_router(menu.router)
app.include_router(tables.router)
app.include_router(orders.router)
app.include_router(inventory.router)
app.include_router(expenses.router)
app.include_router(admin.router)
app.include_router(branches.router)
app.include_router(reports.router)

@app.get("/")
def read_root():
    return {
        "status": "online",
        "service": "RestroFlow API",
        "version": "1.0.0"
    }

@app.get("/api/restaurants/me", response_model=schemas.RestaurantResponse)
def read_current_restaurant(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    restaurant = db.query(models.Restaurant).filter(models.Restaurant.id == current_user.restaurant_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    return restaurant

@app.put("/api/restaurants/me", response_model=schemas.RestaurantResponse)
def update_current_restaurant(
    restaurant_update: schemas.RestaurantUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    # Only allow owner/managers to update restaurant settings
    # Assuming Owner/Manager has permission "settings:edit"
    permissions = [p.name for role in current_user.roles for p in role.permissions]
    role_names = [role.name for role in current_user.roles]
    if "Owner" not in role_names and "settings:edit" not in permissions:
        raise HTTPException(status_code=403, detail="Not enough permissions to edit restaurant settings")

    restaurant = db.query(models.Restaurant).filter(models.Restaurant.id == current_user.restaurant_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
        
    if restaurant_update.phone is not None:
        restaurant.phone = restaurant_update.phone
        
    db.commit()
    db.refresh(restaurant)
    return restaurant

# Real-time WebSocket connection
@app.websocket("/api/ws/orders")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(...)
):
    # Verify JWT Token on handshake
    payload = decode_token(token)
    if not payload:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    user_id_str = payload.get("sub")
    restaurant_id_str = payload.get("restaurant_id")
    if not user_id_str or not restaurant_id_str:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    try:
        restaurant_id = UUID(restaurant_id_str)
    except ValueError:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Add connection
    await manager.connect(websocket, restaurant_id)
    print(f"WS Client connected: User {user_id_str} for Restaurant {restaurant_id_str}")
    
    try:
        while True:
            # Maintain connection, handle client pings / incoming notifications
            data = await websocket.receive_text()
            # If client sends some message, we can echo or log it
            print(f"Received WS message: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket, restaurant_id)
        print(f"WS Client disconnected: User {user_id_str}")
