from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from .. import schemas, crud, auth_utils, dependencies, models

router = APIRouter(prefix="/api/auth", tags=["auth"])

@router.post("/register", response_model=schemas.Token)
def register(user_reg: schemas.UserRegister, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user_reg.email)
    if db_user:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )
    user, restaurant = crud.create_initial_restaurant_and_owner(db, user_reg)
    
    # Generate tokens
    permissions = [p.name for role in user.roles for p in role.permissions]
    access_token = auth_utils.create_access_token(user.id, restaurant.id, permissions)
    refresh_token = auth_utils.create_refresh_token(user.id)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }

@router.post("/login", response_model=schemas.Token)
def login(user_credentials: schemas.UserLogin, db: Session = Depends(get_db)):
    user = crud.get_user_by_email(db, email=user_credentials.email)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not auth_utils.verify_password(user_credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    permissions = [p.name for role in user.roles for p in role.permissions]
    # If the user is "Owner", we can grant all permissions in the token context
    role_names = [role.name for role in user.roles]
    if "Owner" in role_names:
        # Fetch all permissions
        from ..models import Permission
        all_perms = db.query(Permission).all()
        permissions = [p.name for p in all_perms]

    access_token = auth_utils.create_access_token(user.id, user.restaurant_id, permissions)
    refresh_token = auth_utils.create_refresh_token(user.id)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }

@router.post("/refresh", response_model=schemas.Token)
def refresh(refresh_token: str, db: Session = Depends(get_db)):
    payload = auth_utils.decode_token(refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    from uuid import UUID
    try:
        user_id = UUID(user_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token payload"
        )
    
    user = crud.get_user_by_id(db, user_id=user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
        
    permissions = [p.name for role in user.roles for p in role.permissions]
    role_names = [role.name for role in user.roles]
    if "Owner" in role_names:
        from ..models import Permission
        all_perms = db.query(Permission).all()
        permissions = [p.name for p in all_perms]

    access_token = auth_utils.create_access_token(user.id, user.restaurant_id, permissions)
    new_refresh_token = auth_utils.create_refresh_token(user.id)
    
    return {
        "access_token": access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer"
    }

@router.get("/me", response_model=schemas.UserResponse)
def read_users_me(current_user: models.User = Depends(dependencies.get_current_user), db: Session = Depends(get_db)):
    permissions = [p.name for role in current_user.roles for p in role.permissions]
    role_names = [role.name for role in current_user.roles]
    if "Owner" in role_names:
        from ..models import Permission
        all_perms = db.query(Permission).all()
        permissions = [p.name for p in all_perms]

    resp = schemas.UserResponse.model_validate(current_user)
    resp.permissions = permissions
    resp.role = ", ".join(role_names) if role_names else None
    return resp

@router.put("/me", response_model=schemas.UserResponse)
def update_user_me(
    user_update: schemas.UserUpdate,
    current_user: models.User = Depends(dependencies.get_current_user),
    db: Session = Depends(get_db)
):
    current_user.full_name = user_update.full_name
    db.commit()
    db.refresh(current_user)
    
    permissions = [p.name for role in current_user.roles for p in role.permissions]
    role_names = [role.name for role in current_user.roles]
    if "Owner" in role_names:
        from ..models import Permission
        all_perms = db.query(Permission).all()
        permissions = [p.name for p in all_perms]
        
    resp = schemas.UserResponse.model_validate(current_user)
    resp.permissions = permissions
    resp.role = ", ".join(role_names) if role_names else None
    return resp

@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_user_me(
    current_user: models.User = Depends(dependencies.get_current_user),
    db: Session = Depends(get_db)
):
    # Depending on requirements, we might want to soft-delete or cascade delete.
    # For now, we simply delete the user.
    db.delete(current_user)
    db.commit()
    return None
