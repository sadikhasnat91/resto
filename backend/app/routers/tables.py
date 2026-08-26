from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from ..database import get_db
from .. import schemas, crud, dependencies

router = APIRouter(prefix="/api/tables", tags=["tables"])

@router.get("", response_model=List[schemas.TableResponse])
def read_tables(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id)
):
    return crud.get_tables(db, restaurant_id)

@router.post("", response_model=schemas.TableResponse)
def create_table(
    table: schemas.TableCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["settings:edit"]))
):
    return crud.create_table(db, restaurant_id, table)

@router.put("/{id}", response_model=schemas.TableResponse)
def update_table(
    id: UUID,
    table: schemas.TableCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["settings:edit"]))
):
    db_table = crud.update_table(db, restaurant_id, id, table)
    if not db_table:
        raise HTTPException(status_code=404, detail="Table not found")
    return db_table

@router.put("/{id}/status", response_model=schemas.TableResponse)
def update_status(
    id: UUID,
    status_update: schemas.TableStatusUpdate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["orders:update"]))
):
    db_table = crud.update_table_status(db, restaurant_id, id, status_update.status)
    if not db_table:
        raise HTTPException(status_code=404, detail="Table not found")
    return db_table

@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_table(
    id: UUID,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["settings:edit"]))
):
    success = crud.delete_table(db, restaurant_id, id)
    if not success:
        raise HTTPException(status_code=404, detail="Table not found")
    return None
