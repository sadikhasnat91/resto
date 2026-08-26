from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from ..database import get_db
from .. import schemas, crud, dependencies, models
from ..websocket import manager

from typing import List, Optional

router = APIRouter(prefix="/api/orders", tags=["orders"])

@router.get("", response_model=List[schemas.OrderResponse])
def read_orders(
    status: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["orders:view"]))
):
    return crud.get_orders(db, restaurant_id, status=status, search=search)

@router.get("/{id}", response_model=schemas.OrderResponse)
def read_order_by_id(
    id: UUID,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["orders:view"]))
):
    db_order = crud.get_order_by_id(db, restaurant_id, id)
    if not db_order:
        raise HTTPException(status_code=404, detail="Order not found")
    return db_order

@router.post("", response_model=schemas.OrderResponse)
async def create_new_order(
    order: schemas.OrderCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    current_user: models.User = Depends(dependencies.get_current_user),
    has_perm: bool = Depends(dependencies.PermissionChecker(["pos:create"]))
):
    db_order = crud.create_order(db, restaurant_id, current_user.id, order)
    
    # WebSocket Broadcast to tenant
    await manager.broadcast_to_tenant(
        restaurant_id,
        {
            "event": "order_created",
            "order_id": str(db_order.id),
            "order_number": db_order.order_number,
            "status": db_order.status
        }
    )
    
    return db_order

@router.put("/{id}/status", response_model=schemas.OrderResponse)
async def update_order_status(
    id: UUID,
    status_update: schemas.OrderStatusUpdate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["orders:update"]))
):
    db_order = crud.update_order_status(db, restaurant_id, id, status_update.status)
    if not db_order:
        raise HTTPException(status_code=404, detail="Order not found")
        
    # WebSocket Broadcast to tenant
    await manager.broadcast_to_tenant(
        restaurant_id,
        {
            "event": "order_status_changed",
            "order_id": str(db_order.id),
            "order_number": db_order.order_number,
            "status": db_order.status
        }
    )
    
    return db_order

@router.post("/{id}/payment", response_model=schemas.PaymentResponse)
async def checkout_order(
    id: UUID,
    p_req: schemas.PaymentCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["pos:create"]))
):
    db_payment = crud.process_order_payment(db, restaurant_id, id, p_req)
    if not db_payment:
        raise HTTPException(status_code=404, detail="Order not found or processing failed")
        
    # WebSocket Broadcast to tenant
    await manager.broadcast_to_tenant(
        restaurant_id,
        {
            "event": "payment_completed",
            "order_id": str(id),
            "amount": p_req.amount,
            "status": "completed"
        }
    )
    
    return db_payment
