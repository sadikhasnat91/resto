from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime
from uuid import UUID
from ..database import get_db
from .. import schemas, crud, dependencies, models

router = APIRouter(prefix="/api/reports", tags=["reports"])

@router.get("/income", response_model=schemas.IncomeAnalyticsResponse)
def get_income_reports(
    period: str = Query("daily", description="daily, weekly, monthly, yearly, custom"),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    role_names = [role.name for role in current_user.roles]
    if "Owner" not in role_names and "Manager" not in role_names:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access restricted to Owner and Manager roles"
        )
    return crud.get_income_analytics(db, restaurant_id, period=period, start_date=start_date, end_date=end_date)

