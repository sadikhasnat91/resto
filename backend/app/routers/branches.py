from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from ..database import get_db
from .. import schemas, crud, dependencies

router = APIRouter(prefix="/api/branches", tags=["branches"])

@router.get("", response_model=List[schemas.BranchResponse])
def read_branches(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id)
):
    return crud.get_branches(db, restaurant_id)
