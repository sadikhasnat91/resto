from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from ..database import get_db
from .. import schemas, crud, dependencies

router = APIRouter(prefix="/api/expenses", tags=["expenses"])

@router.get("", response_model=List[schemas.ExpenseResponse])
def read_expenses(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["expenses:edit"]))
):
    return crud.get_expenses(db, restaurant_id)

@router.post("", response_model=schemas.ExpenseResponse)
def create_expense(
    exp: schemas.ExpenseCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["expenses:edit"]))
):
    return crud.create_expense(db, restaurant_id, exp)
