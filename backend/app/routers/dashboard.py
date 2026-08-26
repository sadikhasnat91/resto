from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..database import get_db
from .. import schemas, crud, dependencies

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])

@router.get("", response_model=schemas.DashboardSummary)
def get_dashboard(
    db: Session = Depends(get_db),
    restaurant_id: str = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["orders:view"]))
):
    return crud.get_dashboard_summary(db, restaurant_id)
