from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from uuid import UUID
from ..database import get_db
from .. import schemas, crud, dependencies, models

router = APIRouter(prefix="/api/admin", tags=["admin"])

# --- Staff Management ---
class StaffCreate(schemas.BaseModel):
    email: schemas.EmailStr
    full_name: str
    phone: Optional[str] = None
    role_names: List[str]

@router.get("/staff", response_model=List[schemas.UserResponse])
def read_staff(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["staff:manage"]))
):
    users = crud.get_staff_members(db, restaurant_id)
    res = []
    for u in users:
        permissions = [p.name for role in u.roles for p in role.permissions]
        ur = schemas.UserResponse.model_validate(u)
        ur.permissions = permissions
        role_names = [role.name for role in u.roles]
        ur.role = ", ".join(role_names) if role_names else None
        res.append(ur)
    return res

@router.post("/staff", response_model=schemas.UserResponse)
def create_staff(
    staff: StaffCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["staff:manage"]))
):
    db_user = crud.get_user_by_email(db, staff.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
        
    user = crud.create_staff_member(
        db, restaurant_id, staff.email, staff.full_name, staff.phone, staff.role_names
    )
    permissions = [p.name for role in user.roles for p in role.permissions]
    ur = schemas.UserResponse.model_validate(user)
    ur.permissions = permissions
    role_names = [role.name for role in user.roles]
    ur.role = ", ".join(role_names) if role_names else None
    return ur

# --- Customers ---
@router.get("/customers", response_model=List[schemas.CustomerResponse])
def read_customers(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id)
):
    return crud.get_customers(db, restaurant_id)

@router.post("/customers", response_model=schemas.CustomerResponse)
def create_customer(
    customer: schemas.CustomerCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["pos:create"]))
):
    return crud.create_customer(db, restaurant_id, customer)

# --- Suppliers ---
@router.get("/suppliers", response_model=List[schemas.SupplierResponse])
def read_suppliers(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["inventory:edit"]))
):
    return crud.get_suppliers(db, restaurant_id)

@router.post("/suppliers", response_model=schemas.SupplierResponse)
def create_supplier(
    supplier: schemas.SupplierCreate,
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id),
    has_perm: bool = Depends(dependencies.PermissionChecker(["inventory:edit"]))
):
    return crud.create_supplier(db, restaurant_id, supplier)

# --- Notifications ---
@router.get("/notifications", response_model=List[schemas.NotificationResponse])
def read_notifications(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id)
):
    return crud.get_notifications(db, restaurant_id)

@router.post("/notifications/read", status_code=status.HTTP_204_NO_CONTENT)
def mark_read(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id)
):
    crud.mark_notifications_read(db, restaurant_id)
    return None

# --- Roles and Permissions ---
class RoleResponse(schemas.BaseModel):
    id: UUID
    name: str
    description: str = None
    permissions: List[str]

    class Config:
        from_attributes = True

@router.get("/roles", response_model=List[RoleResponse])
def read_roles(
    db: Session = Depends(get_db),
    restaurant_id: UUID = Depends(dependencies.get_current_tenant_id)
):
    # Fetch roles for this restaurant + global roles
    roles = db.query(models.Role).filter(
        (models.Role.restaurant_id == restaurant_id) | (models.Role.restaurant_id == None)
    ).all()
    
    res = []
    for r in roles:
        perms = [p.name for p in r.permissions]
        res.append(
            RoleResponse(id=r.id, name=r.name, description=r.description, permissions=perms)
        )
    return res
