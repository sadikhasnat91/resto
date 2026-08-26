from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from ..database import get_db
from .. import schemas, crud, dependencies

router = APIRouter(prefix="/api/menu", tags=["menu"])

# --- Categories ---
@router.get("/categories", response_model=List[schemas.CategoryResponse])
def read_categories(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id)
):
    return crud.get_categories(db, restaurant_id)

@router.post("/categories", response_model=schemas.CategoryResponse)
def create_category(
    cat: schemas.CategoryCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["menu:edit"]))
):
    return crud.create_category(db, restaurant_id, cat)

@router.put("/categories/{id}", response_model=schemas.CategoryResponse)
def update_category(
    id: UUID,
    cat: schemas.CategoryCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["menu:edit"]))
):
    db_cat = crud.update_category(db, restaurant_id, id, cat)
    if not db_cat:
        raise HTTPException(status_code=404, detail="Category not found")
    return db_cat

@router.delete("/categories/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(
    id: UUID,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["menu:edit"]))
):
    success = crud.delete_category(db, restaurant_id, id)
    if not success:
        raise HTTPException(status_code=404, detail="Category not found")
    return None

# --- Menu Items ---
@router.get("/items", response_model=List[schemas.MenuItemResponse])
def read_menu_items(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id)
):
    return crud.get_menu_items(db, restaurant_id)

@router.post("/items", response_model=schemas.MenuItemResponse)
def create_menu_item(
    item: schemas.MenuItemCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["menu:edit"]))
):
    return crud.create_menu_item(db, restaurant_id, item)

@router.put("/items/{id}", response_model=schemas.MenuItemResponse)
def update_menu_item(
    id: UUID,
    item: schemas.MenuItemCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["menu:edit"]))
):
    db_item = crud.update_menu_item(db, restaurant_id, id, item)
    if not db_item:
        raise HTTPException(status_code=404, detail="Menu item not found")
    return db_item

@router.delete("/items/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_menu_item(
    id: UUID,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["menu:edit"]))
):
    success = crud.delete_menu_item(db, restaurant_id, id)
    if not success:
        raise HTTPException(status_code=404, detail="Menu item not found")
    return None
