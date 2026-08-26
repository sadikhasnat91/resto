from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from ..database import get_db
from .. import schemas, crud, dependencies

router = APIRouter(prefix="/api/inventory", tags=["inventory"])

@router.get("", response_model=List[schemas.InventoryItemResponse])
def read_inventory(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["inventory:edit"]))
):
    return crud.get_inventory(db, restaurant_id)

@router.post("", response_model=schemas.InventoryItemResponse)
def create_item(
    item: schemas.InventoryItemCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["inventory:edit"]))
):
    return crud.create_inventory_item(db, restaurant_id, item)

@router.post("/adjustment", response_model=schemas.InventoryItemResponse)
def adjust_stock(
    tx: schemas.InventoryTransactionCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["inventory:edit"]))
):
    db_item = crud.adjust_inventory_stock(db, restaurant_id, tx)
    if not db_item:
        raise HTTPException(status_code=404, detail="Inventory item not found")
    return db_item

@router.get("/transactions/{item_id}", response_model=List[schemas.InventoryTransactionResponse])
def read_transactions(
    item_id: UUID,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["inventory:edit"]))
):
    from ..models import InventoryTransaction
    return db.query(InventoryTransaction).filter(
        InventoryTransaction.restaurant_id == restaurant_id,
        InventoryTransaction.inventory_item_id == item_id
    ).all()
