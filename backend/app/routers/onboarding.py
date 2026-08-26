from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from .. import schemas, crud, dependencies

router = APIRouter(prefix="/api/onboarding", tags=["onboarding"])

@router.post("", response_model=schemas.RestaurantResponse)
def complete_onboarding(
    onboarding: schemas.RestaurantOnboarding,
    db: Session = Depends(get_db),
    restaurant_id: str = Depends(dependencies.get_current_tenant_id)
):
    restaurant = crud.onboard_restaurant(db, restaurant_id, onboarding)
    if not restaurant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Restaurant not found"
        )
    return restaurant

@router.get("/status", response_model=schemas.RestaurantResponse)
def get_restaurant_info(
    db: Session = Depends(get_db),
    restaurant_id: str = Depends(dependencies.get_current_tenant_id)
):
    from ..models import Restaurant
    restaurant = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not restaurant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Restaurant not found"
        )
    return restaurant
