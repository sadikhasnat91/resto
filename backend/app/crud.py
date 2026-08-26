from sqlalchemy.orm import Session
from sqlalchemy import func, and_, desc
from uuid import UUID
from datetime import datetime, date, timedelta
from typing import List, Optional
from . import models, schemas
from .auth_utils import get_password_hash

# --- User & Auth CRUD ---
def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email).first()

def get_user_by_id(db: Session, user_id: UUID):
    return db.query(models.User).filter(models.User.id == user_id).first()

def create_initial_restaurant_and_owner(db: Session, user_reg: schemas.UserRegister):
    # 1. Create Restaurant
    db_restaurant = models.Restaurant(
        name=user_reg.restaurant_name,
        currency="USD",
        timezone="UTC"
    )
    db.add(db_restaurant)
    db.flush() # Populate ID

    # 2. Create Owner User
    db_user = models.User(
        restaurant_id=db_restaurant.id,
        email=user_reg.email,
        hashed_password=get_password_hash(user_reg.password),
        full_name=user_reg.full_name,
        status="active"
    )
    db.add(db_user)
    db.flush()

    # 3. Create Default Owner Role & Assign to User
    owner_role = models.Role(
        restaurant_id=db_restaurant.id,
        name="Owner",
        description="Full access to the restaurant operations and settings",
        is_custom=False
    )
    db.add(owner_role)
    db.flush()

    # Link user to role
    db.execute(
        models.user_roles.insert().values(user_id=db_user.id, role_id=owner_role.id)
    )

    db.commit()
    db.refresh(db_user)
    db.refresh(db_restaurant)
    return db_user, db_restaurant

# --- Restaurant Onboarding ---
def onboard_restaurant(db: Session, restaurant_id: UUID, onboarding: schemas.RestaurantOnboarding):
    db_restaurant = db.query(models.Restaurant).filter(models.Restaurant.id == restaurant_id).first()
    if not db_restaurant:
        return None

    # Update info
    db_restaurant.name = onboarding.name
    db_restaurant.phone = onboarding.phone
    db_restaurant.email = onboarding.email
    db_restaurant.address = onboarding.address
    db_restaurant.currency = onboarding.currency
    db_restaurant.timezone = onboarding.timezone

    # Create Branch
    db_branch = models.Branch(
        restaurant_id=restaurant_id,
        name=onboarding.branch_name,
        address=onboarding.address,
        phone=onboarding.phone
    )
    db.add(db_branch)
    db.flush()

    # Create default Categories
    for idx, cat_name in enumerate(onboarding.initial_categories or ["Starters", "Mains", "Desserts", "Beverages"]):
        db_cat = models.Category(
            restaurant_id=restaurant_id,
            name=cat_name,
            display_order=idx
        )
        db.add(db_cat)

    # Create default Tables
    for i in range(1, (onboarding.initial_tables or 5) + 1):
        db_table = models.RestaurantTable(
            restaurant_id=restaurant_id,
            branch_id=db_branch.id,
            table_number=f"T{i}",
            capacity=4,
            status="available",
            section="Main Hall"
        )
        db.add(db_table)

    db.commit()
    db.refresh(db_restaurant)
    return db_restaurant

# --- Categories CRUD ---
def get_categories(db: Session, restaurant_id: UUID) -> List[models.Category]:
    return db.query(models.Category).filter(models.Category.restaurant_id == restaurant_id).order_by(models.Category.display_order).all()

def create_category(db: Session, restaurant_id: UUID, cat: schemas.CategoryCreate) -> models.Category:
    db_cat = models.Category(
        restaurant_id=restaurant_id,
        name=cat.name,
        display_order=cat.display_order
    )
    db.add(db_cat)
    db.commit()
    db.refresh(db_cat)
    return db_cat

def update_category(db: Session, restaurant_id: UUID, cat_id: UUID, cat_update: schemas.CategoryCreate) -> Optional[models.Category]:
    db_cat = db.query(models.Category).filter(
        and_(models.Category.id == cat_id, models.Category.restaurant_id == restaurant_id)
    ).first()
    if not db_cat:
        return None
    db_cat.name = cat_update.name
    db_cat.display_order = cat_update.display_order
    db.commit()
    db.refresh(db_cat)
    return db_cat

def delete_category(db: Session, restaurant_id: UUID, cat_id: UUID) -> bool:
    db_cat = db.query(models.Category).filter(
        and_(models.Category.id == cat_id, models.Category.restaurant_id == restaurant_id)
    ).first()
    if not db_cat:
        return False
    db.delete(db_cat)
    db.commit()
    return True

# --- Menu Items CRUD ---
def get_menu_items(db: Session, restaurant_id: UUID) -> List[models.MenuItem]:
    return db.query(models.MenuItem).filter(models.MenuItem.restaurant_id == restaurant_id).all()

def create_menu_item(db: Session, restaurant_id: UUID, item: schemas.MenuItemCreate) -> models.MenuItem:
    db_item = models.MenuItem(
        restaurant_id=restaurant_id,
        category_id=item.category_id,
        name=item.name,
        description=item.description,
        price=item.price,
        cost_price=item.cost_price,
        image_url=item.image_url,
        SKU=item.SKU,
        is_available=item.is_available,
        preparation_time_minutes=item.preparation_time_minutes,
        tax_rate=item.tax_rate,
        discount_rate=item.discount_rate
    )
    db.add(db_item)
    db.flush()

    for var in item.variants:
        db_var = models.MenuItemVariant(
            menu_item_id=db_item.id,
            name=var.name,
            price_override=var.price_override
        )
        db.add(db_var)

    for add in item.addons:
        db_add = models.MenuItemAddon(
            menu_item_id=db_item.id,
            name=add.name,
            price=add.price
        )
        db.add(db_add)

    db.commit()
    db.refresh(db_item)
    return db_item

def update_menu_item(db: Session, restaurant_id: UUID, item_id: UUID, item_update: schemas.MenuItemCreate) -> Optional[models.MenuItem]:
    db_item = db.query(models.MenuItem).filter(
        and_(models.MenuItem.id == item_id, models.MenuItem.restaurant_id == restaurant_id)
    ).first()
    if not db_item:
        return None

    db_item.category_id = item_update.category_id
    db_item.name = item_update.name
    db_item.description = item_update.description
    db_item.price = item_update.price
    db_item.cost_price = item_update.cost_price
    db_item.image_url = item_update.image_url
    db_item.SKU = item_update.SKU
    db_item.is_available = item_update.is_available
    db_item.preparation_time_minutes = item_update.preparation_time_minutes
    db_item.tax_rate = item_update.tax_rate
    db_item.discount_rate = item_update.discount_rate

    # Recreate variants and addons simply
    db.query(models.MenuItemVariant).filter(models.MenuItemVariant.menu_item_id == item_id).delete()
    db.query(models.MenuItemAddon).filter(models.MenuItemAddon.menu_item_id == item_id).delete()

    for var in item_update.variants:
        db_var = models.MenuItemVariant(
            menu_item_id=db_item.id,
            name=var.name,
            price_override=var.price_override
        )
        db.add(db_var)

    for add in item_update.addons:
        db_add = models.MenuItemAddon(
            menu_item_id=db_item.id,
            name=add.name,
            price=add.price
        )
        db.add(db_add)

    db.commit()
    db.refresh(db_item)
    return db_item

def delete_menu_item(db: Session, restaurant_id: UUID, item_id: UUID) -> bool:
    db_item = db.query(models.MenuItem).filter(
        and_(models.MenuItem.id == item_id, models.MenuItem.restaurant_id == restaurant_id)
    ).first()
    if not db_item:
        return False
    db.delete(db_item)
    db.commit()
    return True

# --- Tables CRUD ---
def get_tables(db: Session, restaurant_id: UUID) -> List[models.RestaurantTable]:
    return db.query(models.RestaurantTable).filter(models.RestaurantTable.restaurant_id == restaurant_id).all()

def create_table(db: Session, restaurant_id: UUID, table: schemas.TableCreate) -> models.RestaurantTable:
    db_table = models.RestaurantTable(
        restaurant_id=restaurant_id,
        branch_id=table.branch_id,
        table_number=table.table_number,
        capacity=table.capacity,
        status="available",
        section=table.section
    )
    db.add(db_table)
    db.commit()
    db.refresh(db_table)
    return db_table

def update_table(db: Session, restaurant_id: UUID, table_id: UUID, table_update: schemas.TableCreate) -> Optional[models.RestaurantTable]:
    db_table = db.query(models.RestaurantTable).filter(
        and_(models.RestaurantTable.id == table_id, models.RestaurantTable.restaurant_id == restaurant_id)
    ).first()
    if not db_table:
        return None
    db_table.table_number = table_update.table_number
    db_table.capacity = table_update.capacity
    db_table.section = table_update.section
    db.commit()
    db.refresh(db_table)
    return db_table

def update_table_status(db: Session, restaurant_id: UUID, table_id: UUID, status: str) -> Optional[models.RestaurantTable]:
    db_table = db.query(models.RestaurantTable).filter(
        and_(models.RestaurantTable.id == table_id, models.RestaurantTable.restaurant_id == restaurant_id)
    ).first()
    if not db_table:
        return None
    db_table.status = status
    db.commit()
    db.refresh(db_table)
    return db_table

def delete_table(db: Session, restaurant_id: UUID, table_id: UUID) -> bool:
    db_table = db.query(models.RestaurantTable).filter(
        and_(models.RestaurantTable.id == table_id, models.RestaurantTable.restaurant_id == restaurant_id)
    ).first()
    if not db_table:
        return False
    db.delete(db_table)
    db.commit()
    return True

# --- Branches CRUD ---
def get_branches(db: Session, restaurant_id: UUID) -> List[models.Branch]:
    return db.query(models.Branch).filter(models.Branch.restaurant_id == restaurant_id).all()

# --- Customers CRUD ---
def get_customers(db: Session, restaurant_id: UUID) -> List[models.Customer]:
    return db.query(models.Customer).filter(models.Customer.restaurant_id == restaurant_id).all()

def create_customer(db: Session, restaurant_id: UUID, customer: schemas.CustomerCreate) -> models.Customer:
    db_cust = models.Customer(
        restaurant_id=restaurant_id,
        name=customer.name,
        phone=customer.phone,
        email=customer.email,
        address=customer.address,
        outstanding_balance=0.0
    )
    db.add(db_cust)
    db.commit()
    db.refresh(db_cust)
    return db_cust

# --- Suppliers CRUD ---
def get_suppliers(db: Session, restaurant_id: UUID) -> List[models.Supplier]:
    return db.query(models.Supplier).filter(models.Supplier.restaurant_id == restaurant_id).all()

def create_supplier(db: Session, restaurant_id: UUID, supplier: schemas.SupplierCreate) -> models.Supplier:
    db_supp = models.Supplier(
        restaurant_id=restaurant_id,
        name=supplier.name,
        phone=supplier.phone,
        email=supplier.email,
        address=supplier.address
    )
    db.add(db_supp)
    db.commit()
    db.refresh(db_supp)
    return db_supp

# --- Orders & POS Checkout ---
def get_orders(
    db: Session,
    restaurant_id: UUID,
    status: Optional[str] = None,
    search: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None
) -> List[models.Order]:
    query = db.query(models.Order).filter(models.Order.restaurant_id == restaurant_id)
    if status and status != "all":
        query = query.filter(models.Order.status == status)
    if search:
        query = query.filter(models.Order.order_number.ilike(f"%{search}%"))
    if start_date:
        query = query.filter(models.Order.created_at >= start_date)
    if end_date:
        query = query.filter(models.Order.created_at <= end_date)
    return query.order_by(desc(models.Order.created_at)).all()

def get_order_by_id(db: Session, restaurant_id: UUID, order_id: UUID) -> Optional[models.Order]:
    return db.query(models.Order).filter(
        and_(models.Order.id == order_id, models.Order.restaurant_id == restaurant_id)
    ).first()

def create_order(db: Session, restaurant_id: UUID, user_id: UUID, order: schemas.OrderCreate) -> models.Order:
    # 1. Generate Order Number
    count = db.query(models.Order).filter(models.Order.restaurant_id == restaurant_id).count()
    order_number = f"ORD-{datetime.utcnow().strftime('%y%m%d')}-{count+1:04d}"

    # 2. Build Order Base
    db_order = models.Order(
        restaurant_id=restaurant_id,
        branch_id=order.branch_id,
        table_id=order.table_id,
        customer_id=order.customer_id,
        user_id=user_id,
        order_number=order_number,
        order_type=order.order_type,
        status="pending",
        notes=order.notes,
        discount_amount=order.discount_amount
    )
    db.add(db_order)
    db.flush()

    subtotal = 0.0
    tax_total = 0.0

    # 3. Create items
    for item in order.items:
        db_menu_item = db.query(models.MenuItem).filter(models.MenuItem.id == item.menu_item_id).first()
        if not db_menu_item:
            continue

        unit_price = db_menu_item.price
        # Check variant override
        if item.selected_variant_id:
            db_var = db.query(models.MenuItemVariant).filter(models.MenuItemVariant.id == item.selected_variant_id).first()
            if db_var and db_var.price_override is not None:
                unit_price = db_var.price_override

        # Create OrderItem
        db_order_item = models.OrderItem(
            order_id=db_order.id,
            menu_item_id=item.menu_item_id,
            quantity=item.quantity,
            unit_price=unit_price,
            notes=item.notes,
            selected_variant_id=item.selected_variant_id
        )
        db.add(db_order_item)
        db.flush()

        item_subtotal = unit_price * item.quantity

        # Create OrderItemAddons
        for addon_id in item.addon_ids:
            db_addon = db.query(models.MenuItemAddon).filter(models.MenuItemAddon.id == addon_id).first()
            if db_addon:
                db.execute(
                    models.order_item_addons.insert().values(order_item_id=db_order_item.id, addon_id=db_addon.id)
                )
                item_subtotal += db_addon.price * item.quantity

        # Update totals
        subtotal += item_subtotal
        tax_total += item_subtotal * (db_menu_item.tax_rate / 100.0)

    db_order.subtotal = subtotal
    db_order.tax_amount = tax_total
    db_order.total_amount = (subtotal + tax_total) - db_order.discount_amount

    # Update table status if dine-in
    if order.order_type == "dine_in" and order.table_id:
        db_table = db.query(models.RestaurantTable).filter(models.RestaurantTable.id == order.table_id).first()
        if db_table:
            db_table.status = "occupied"

    db.commit()
    db.refresh(db_order)
    return db_order

def update_order_status(db: Session, restaurant_id: UUID, order_id: UUID, status: str) -> Optional[models.Order]:
    db_order = db.query(models.Order).filter(
        and_(models.Order.id == order_id, models.Order.restaurant_id == restaurant_id)
    ).first()
    if not db_order:
        return None

    db_order.status = status

    # If order is completed or cancelled, release the table
    if status in ["completed", "cancelled"] and db_order.table_id:
        db_table = db.query(models.RestaurantTable).filter(models.RestaurantTable.id == db_order.table_id).first()
        if db_table:
            db_table.status = "cleaning" # Move to cleaning status

    db.commit()
    db.refresh(db_order)
    return db_order

def process_order_payment(db: Session, restaurant_id: UUID, order_id: UUID, p_req: schemas.PaymentCreate) -> Optional[models.Payment]:
    db_order = db.query(models.Order).filter(
        and_(models.Order.id == order_id, models.Order.restaurant_id == restaurant_id)
    ).first()
    if not db_order:
        return None

    # Create Payment
    db_payment = models.Payment(
        restaurant_id=restaurant_id,
        order_id=order_id,
        payment_method=p_req.payment_method,
        amount=p_req.amount,
        status="completed",
        transaction_id=p_req.transaction_id
    )
    db.add(db_payment)

    # Check total payments to complete order
    total_paid = sum([p.amount for p in db_order.payments if p.status == "completed"]) + p_req.amount
    if total_paid >= db_order.total_amount:
        # Note: We do NOT set db_order.status = "completed" here anymore.
        # Payment completion does not mean food preparation is complete.
        # KDS needs to process it from pending -> preparing -> ready -> completed.
        pass

    # Add transaction history to customer if associated
    if db_order.customer_id:
        db_customer = db.query(models.Customer).filter(models.Customer.id == db_order.customer_id).first()
        if db_customer:
            db_customer.outstanding_balance += (db_order.total_amount - total_paid)

    db.commit()
    db.refresh(db_payment)
    return db_payment

# --- Inventory CRUD ---
def get_inventory(db: Session, restaurant_id: UUID) -> List[models.InventoryItem]:
    return db.query(models.InventoryItem).filter(models.InventoryItem.restaurant_id == restaurant_id).all()

def create_inventory_item(db: Session, restaurant_id: UUID, item: schemas.InventoryItemCreate) -> models.InventoryItem:
    db_item = models.InventoryItem(
        restaurant_id=restaurant_id,
        name=item.name,
        SKU=item.SKU,
        unit=item.unit,
        current_stock=item.current_stock,
        minimum_stock=item.minimum_stock,
        cost=item.cost,
        supplier_id=item.supplier_id
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

def adjust_inventory_stock(db: Session, restaurant_id: UUID, tx: schemas.InventoryTransactionCreate) -> Optional[models.InventoryItem]:
    db_item = db.query(models.InventoryItem).filter(
        and_(models.InventoryItem.id == tx.inventory_item_id, models.InventoryItem.restaurant_id == restaurant_id)
    ).first()
    if not db_item:
        return None

    # Create transaction
    db_tx = models.InventoryTransaction(
        restaurant_id=restaurant_id,
        inventory_item_id=tx.inventory_item_id,
        type=tx.type,
        quantity=tx.quantity,
        reason=tx.reason
    )
    db.add(db_tx)

    # Adjust stock
    if tx.type in ["in", "purchase"]:
        db_item.current_stock += tx.quantity
    elif tx.type in ["out", "adjustment"]:
        db_item.current_stock -= tx.quantity

    db.commit()
    db.refresh(db_item)
    return db_item

# --- Expenses CRUD ---
def get_expenses(db: Session, restaurant_id: UUID) -> List[models.Expense]:
    return db.query(models.Expense).filter(models.Expense.restaurant_id == restaurant_id).order_by(desc(models.Expense.date)).all()

def create_expense(db: Session, restaurant_id: UUID, exp: schemas.ExpenseCreate) -> models.Expense:
    db_exp = models.Expense(
        restaurant_id=restaurant_id,
        category=exp.category,
        amount=exp.amount,
        payment_method=exp.payment_method,
        description=exp.description
    )
    db.add(db_exp)
    db.commit()
    db.refresh(db_exp)
    return db_exp

# --- Notifications CRUD ---
def get_notifications(db: Session, restaurant_id: UUID) -> List[models.Notification]:
    return db.query(models.Notification).filter(models.Notification.restaurant_id == restaurant_id).order_by(desc(models.Notification.created_at)).all()

def mark_notifications_read(db: Session, restaurant_id: UUID):
    db.query(models.Notification).filter(models.Notification.restaurant_id == restaurant_id).update({models.Notification.is_read: True})
    db.commit()

# --- Dashboard API ---
def get_dashboard_summary(db: Session, restaurant_id: UUID) -> schemas.DashboardSummary:
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)

    # 1. KPI Today Sales
    today_sales = db.query(func.sum(models.Order.total_amount)).filter(
        and_(
            models.Order.restaurant_id == restaurant_id,
            models.Order.created_at >= today_start,
            models.Order.created_at < today_end,
            models.Order.status == "completed"
        )
    ).scalar() or 0.0

    # 2. KPI Today Orders Count
    orders_count = db.query(func.count(models.Order.id)).filter(
        and_(
            models.Order.restaurant_id == restaurant_id,
            models.Order.created_at >= today_start,
            models.Order.created_at < today_end
        )
    ).scalar() or 0

    # 3. Average Order Value
    avg_order_value = 0.0
    if orders_count > 0:
        avg_order_value = db.query(func.avg(models.Order.total_amount)).filter(
            and_(
                models.Order.restaurant_id == restaurant_id,
                models.Order.created_at >= today_start,
                models.Order.created_at < today_end
            )
        ).scalar() or 0.0

    # 4. Today Expenses
    today_expenses = db.query(func.sum(models.Expense.amount)).filter(
        and_(
            models.Expense.restaurant_id == restaurant_id,
            models.Expense.date >= today_start,
            models.Expense.date < today_end
        )
    ).scalar() or 0.0

    now = datetime.utcnow()
    week_start = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    year_start = now.replace(month=1, day=1, hour=0, minute=0, second=0, microsecond=0)

    week_sales = db.query(func.sum(models.Order.total_amount)).filter(
        and_(
            models.Order.restaurant_id == restaurant_id,
            models.Order.created_at >= week_start,
            models.Order.status == "completed"
        )
    ).scalar() or 0.0

    month_sales = db.query(func.sum(models.Order.total_amount)).filter(
        and_(
            models.Order.restaurant_id == restaurant_id,
            models.Order.created_at >= month_start,
            models.Order.status == "completed"
        )
    ).scalar() or 0.0

    year_sales = db.query(func.sum(models.Order.total_amount)).filter(
        and_(
            models.Order.restaurant_id == restaurant_id,
            models.Order.created_at >= year_start,
            models.Order.status == "completed"
        )
    ).scalar() or 0.0

    net_revenue = today_sales - today_expenses

    kpi = schemas.DashboardKPI(
        today_sales=today_sales,
        week_sales=week_sales,
        month_sales=month_sales,
        year_sales=year_sales,
        orders_count=orders_count,
        avg_order_value=avg_order_value,
        today_expenses=today_expenses,
        net_revenue=net_revenue
    )

    # 5. Sales Chart Series (Last 7 Days)
    sales_chart = []
    for i in range(6, -1, -1):
        day_date = date.today() - timedelta(days=i)
        day_start = datetime.combine(day_date, datetime.min.time())
        day_end = datetime.combine(day_date, datetime.max.time())

        sales_sum = db.query(func.sum(models.Order.total_amount)).filter(
            and_(
                models.Order.restaurant_id == restaurant_id,
                models.Order.created_at >= day_start,
                models.Order.created_at < day_end,
                models.Order.status == "completed"
            )
        ).scalar() or 0.0

        sales_chart.append(
            schemas.DailySalesSeries(
                date=day_date.strftime("%a"),
                amount=sales_sum
            )
        )

    # 6. Top Selling Items
    top_items_query = db.query(
        models.MenuItem.name,
        func.sum(models.OrderItem.quantity).label('qty'),
        func.sum(models.OrderItem.quantity * models.OrderItem.unit_price).label('rev')
    ).join(
        models.OrderItem, models.MenuItem.id == models.OrderItem.menu_item_id
    ).join(
        models.Order, models.Order.id == models.OrderItem.order_id
    ).filter(
        and_(
            models.MenuItem.restaurant_id == restaurant_id,
            models.Order.status == "completed"
        )
    ).group_by(
        models.MenuItem.name
    ).order_by(
        desc('qty')
    ).limit(5).all()

    top_items = [
        schemas.TopItemSeries(name=row[0], quantity=int(row[1]), revenue=row[2])
        for row in top_items_query
    ]

    # 7. Recent Orders
    recent_orders = db.query(models.Order).filter(
        models.Order.restaurant_id == restaurant_id
    ).order_by(desc(models.Order.created_at)).limit(5).all()

    # 8. Low Stock
    low_stock = db.query(models.InventoryItem).filter(
        and_(
            models.InventoryItem.restaurant_id == restaurant_id,
            models.InventoryItem.current_stock <= models.InventoryItem.minimum_stock
        )
    ).limit(5).all()

    # 9. Recent Expenses
    recent_expenses = db.query(models.Expense).filter(
        models.Expense.restaurant_id == restaurant_id
    ).order_by(desc(models.Expense.date)).limit(5).all()

    return schemas.DashboardSummary(
        kpi=kpi,
        sales_chart=sales_chart,
        top_items=top_items,
        recent_orders=recent_orders,
        low_stock=low_stock,
        recent_expenses=recent_expenses
    )

# --- Staff CRUD ---
def get_staff_members(db: Session, restaurant_id: UUID) -> List[models.User]:
    return db.query(models.User).filter(models.User.restaurant_id == restaurant_id).all()

def create_staff_member(db: Session, restaurant_id: UUID, email: str, full_name: str, phone: Optional[str], role_names: List[str]):
    # Create User
    db_user = models.User(
        restaurant_id=restaurant_id,
        email=email,
        hashed_password=get_password_hash("StaffPassword123!"), # Temporary password
        full_name=full_name,
        phone=phone,
        status="active"
    )
    db.add(db_user)
    db.flush()

    for r_name in role_names:
        role = db.query(models.Role).filter(
            and_(
                models.Role.name == r_name,
                models.Role.restaurant_id == restaurant_id
            )
        ).first()
        if not role:
            # Check global
            role = db.query(models.Role).filter(
                and_(
                    models.Role.name == r_name,
                    models.Role.restaurant_id == None
                )
            ).first()

        if role:
            db.execute(
                models.user_roles.insert().values(user_id=db_user.id, role_id=role.id)
            )

    db.commit()
    db.refresh(db_user)
    return db_user

def get_income_analytics(
    db: Session,
    restaurant_id: UUID,
    period: str = "daily",
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None
) -> schemas.IncomeAnalyticsResponse:
    now = datetime.utcnow()
    
    if period == "daily":
        start_dt = now.replace(hour=0, minute=0, second=0, microsecond=0)
        end_dt = start_dt + timedelta(days=1)
    elif period == "weekly":
        start_dt = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
        end_dt = start_dt + timedelta(days=7)
    elif period == "monthly":
        start_dt = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        if now.month == 12:
            end_dt = start_dt.replace(year=now.year + 1, month=1)
        else:
            end_dt = start_dt.replace(month=now.month + 1)
    elif period == "yearly":
        start_dt = now.replace(month=1, day=1, hour=0, minute=0, second=0, microsecond=0)
        end_dt = start_dt.replace(year=now.year + 1)
    elif period == "custom" and start_date and end_date:
        start_dt = start_date
        end_dt = end_date
    else:
        start_dt = now.replace(hour=0, minute=0, second=0, microsecond=0)
        end_dt = start_dt + timedelta(days=1)

    orders_query = db.query(models.Order).filter(
        and_(
            models.Order.restaurant_id == restaurant_id,
            models.Order.created_at >= start_dt,
            models.Order.created_at < end_dt
        )
    )
    orders = orders_query.all()

    total_orders = len(orders)
    completed_orders_list = [o for o in orders if o.status == "completed"]
    completed_orders = len(completed_orders_list)
    cancelled_orders = len([o for o in orders if o.status == "cancelled"])

    total_income = sum(o.total_amount for o in completed_orders_list)
    avg_order_value = (total_income / completed_orders) if completed_orders > 0 else 0.0

    expenses_sum = db.query(func.sum(models.Expense.amount)).filter(
        and_(
            models.Expense.restaurant_id == restaurant_id,
            models.Expense.date >= start_dt,
            models.Expense.date < end_dt
        )
    ).scalar() or 0.0

    net_profit = total_income - expenses_sum

    payments = db.query(models.Payment).join(
        models.Order, models.Order.id == models.Payment.order_id
    ).filter(
        and_(
            models.Payment.restaurant_id == restaurant_id,
            models.Payment.status == "completed",
            models.Order.created_at >= start_dt,
            models.Order.created_at < end_dt
        )
    ).all()

    method_totals = {}
    total_payment_amt = 0.0
    for p in payments:
        method = p.payment_method or "cash"
        method_totals[method] = method_totals.get(method, 0.0) + p.amount
        total_payment_amt += p.amount

    payment_methods_list = []
    for m_name, m_amt in method_totals.items():
        pct = (m_amt / total_payment_amt * 100.0) if total_payment_amt > 0 else 0.0
        payment_methods_list.append(
            schemas.PaymentMethodBreakdown(method=m_name, amount=m_amt, percentage=round(pct, 1))
        )

    income_chart = []
    if period == "daily":
        for hour in range(0, 24, 3):
            h_start = start_dt.replace(hour=hour, minute=0, second=0)
            h_end = h_start + timedelta(hours=3)
            h_orders = [o for o in completed_orders_list if h_start <= o.created_at < h_end]
            h_inc = sum(o.total_amount for o in h_orders)
            label = f"{hour:02d}:00"
            income_chart.append(
                schemas.IncomeChartSeries(
                    label=label,
                    date=h_start.strftime("%Y-%m-%d %H:%M"),
                    income=h_inc,
                    orders_count=len(h_orders)
                )
            )
    elif period in ["weekly", "monthly", "custom"]:
        num_days = (end_dt - start_dt).days or 1
        for d in range(num_days):
            d_start = start_dt + timedelta(days=d)
            d_end = d_start + timedelta(days=1)
            d_orders = [o for o in completed_orders_list if d_start <= o.created_at < d_end]
            d_inc = sum(o.total_amount for o in d_orders)
            label = d_start.strftime("%a %d") if period == "weekly" else d_start.strftime("%d %b")
            income_chart.append(
                schemas.IncomeChartSeries(
                    label=label,
                    date=d_start.strftime("%Y-%m-%d"),
                    income=d_inc,
                    orders_count=len(d_orders)
                )
            )
    elif period == "yearly":
        for m in range(1, 13):
            m_start = start_dt.replace(month=m, day=1, hour=0, minute=0, second=0)
            if m == 12:
                m_end = start_dt.replace(year=start_dt.year + 1, month=1, day=1)
            else:
                m_end = start_dt.replace(month=m + 1, day=1)
            m_orders = [o for o in completed_orders_list if m_start <= o.created_at < m_end]
            m_inc = sum(o.total_amount for o in m_orders)
            label = m_start.strftime("%b")
            income_chart.append(
                schemas.IncomeChartSeries(
                    label=label,
                    date=m_start.strftime("%Y-%m"),
                    income=m_inc,
                    orders_count=len(m_orders)
                )
            )

    top_items_query = db.query(
        models.MenuItem.name,
        func.sum(models.OrderItem.quantity).label('qty'),
        func.sum(models.OrderItem.quantity * models.OrderItem.unit_price).label('rev')
    ).join(
        models.OrderItem, models.MenuItem.id == models.OrderItem.menu_item_id
    ).join(
        models.Order, models.Order.id == models.OrderItem.order_id
    ).filter(
        and_(
            models.MenuItem.restaurant_id == restaurant_id,
            models.Order.status == "completed",
            models.Order.created_at >= start_dt,
            models.Order.created_at < end_dt
        )
    ).group_by(
        models.MenuItem.name
    ).order_by(
        desc('qty')
    ).limit(5).all()

    top_items = [
        schemas.TopItemSeries(name=row[0], quantity=int(row[1]), revenue=row[2])
        for row in top_items_query
    ]

    cat_rev_query = db.query(
        models.Category.name,
        func.sum(models.OrderItem.quantity * models.OrderItem.unit_price).label('rev')
    ).join(
        models.MenuItem, models.MenuItem.category_id == models.Category.id
    ).join(
        models.OrderItem, models.MenuItem.id == models.OrderItem.menu_item_id
    ).join(
        models.Order, models.Order.id == models.OrderItem.order_id
    ).filter(
        and_(
            models.Category.restaurant_id == restaurant_id,
            models.Order.status == "completed",
            models.Order.created_at >= start_dt,
            models.Order.created_at < end_dt
        )
    ).group_by(
        models.Category.name
    ).all()

    revenue_by_category = []
    for row in cat_rev_query:
        c_name, c_rev = row[0], row[1] or 0.0
        c_pct = (c_rev / total_income * 100.0) if total_income > 0 else 0.0
        revenue_by_category.append(
            schemas.CategoryRevenueSeries(name=c_name, revenue=c_rev, percentage=round(c_pct, 1))
        )

    return schemas.IncomeAnalyticsResponse(
        period=period,
        total_income=total_income,
        total_orders=total_orders,
        completed_orders=completed_orders,
        cancelled_orders=cancelled_orders,
        avg_order_value=avg_order_value,
        total_expenses=expenses_sum,
        net_profit=net_profit,
        payment_methods=payment_methods_list,
        income_chart=income_chart,
        top_items=top_items,
        revenue_by_category=revenue_by_category
    )

