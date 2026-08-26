import uuid
from datetime import datetime
from sqlalchemy import Column, String, Float, Integer, Boolean, DateTime, ForeignKey, Table, Enum, UUID
from sqlalchemy.orm import relationship
from .database import Base

# Association table for User <-> Role (Many-to-Many)
user_roles = Table(
    'user_roles',
    Base.metadata,
    Column('user_id', UUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'), primary_key=True),
    Column('role_id', UUID(as_uuid=True), ForeignKey('roles.id', ondelete='CASCADE'), primary_key=True)
)

# Association table for Role <-> Permission (Many-to-Many)
role_permissions = Table(
    'role_permissions',
    Base.metadata,
    Column('role_id', UUID(as_uuid=True), ForeignKey('roles.id', ondelete='CASCADE'), primary_key=True),
    Column('permission_id', UUID(as_uuid=True), ForeignKey('permissions.id', ondelete='CASCADE'), primary_key=True)
)

class Restaurant(Base):
    __tablename__ = "restaurants"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    logo_url = Column(String, nullable=True)
    phone = Column(String, nullable=True)
    email = Column(String, nullable=True)
    address = Column(String, nullable=True)
    currency = Column(String, default="USD")
    timezone = Column(String, default="UTC")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    users = relationship("User", back_populates="restaurant")
    branches = relationship("Branch", back_populates="restaurant")
    roles = relationship("Role", back_populates="restaurant")
    categories = relationship("Category", back_populates="restaurant")
    menu_items = relationship("MenuItem", back_populates="restaurant")
    tables = relationship("RestaurantTable", back_populates="restaurant")
    orders = relationship("Order", back_populates="restaurant")
    payments = relationship("Payment", back_populates="restaurant")
    customers = relationship("Customer", back_populates="restaurant")
    inventory_items = relationship("InventoryItem", back_populates="restaurant")
    suppliers = relationship("Supplier", back_populates="restaurant")
    expenses = relationship("Expense", back_populates="restaurant")
    notifications = relationship("Notification", back_populates="restaurant")
    subscriptions = relationship("Subscription", back_populates="restaurant")

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    status = Column(String, default="active") # active, inactive, pending
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="users")
    roles = relationship("Role", secondary=user_roles, back_populates="users")
    orders = relationship("Order", back_populates="staff")
    notifications = relationship("Notification", back_populates="user")

class Role(Base):
    __tablename__ = "roles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=True) # Null for global roles
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    is_custom = Column(Boolean, default=True)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="roles")
    users = relationship("User", secondary=user_roles, back_populates="roles")
    permissions = relationship("Permission", secondary=role_permissions, back_populates="roles")

class Permission(Base):
    __tablename__ = "permissions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, unique=True, nullable=False) # e.g. "pos:create", "menu:edit"
    description = Column(String, nullable=True)

    # Relationships
    roles = relationship("Role", secondary=role_permissions, back_populates="permissions")

class Branch(Base):
    __tablename__ = "branches"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    name = Column(String, nullable=False)
    address = Column(String, nullable=True)
    phone = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="branches")
    tables = relationship("RestaurantTable", back_populates="branch")
    orders = relationship("Order", back_populates="branch")

class Category(Base):
    __tablename__ = "categories"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    name = Column(String, nullable=False)
    display_order = Column(Integer, default=0)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="categories")
    menu_items = relationship("MenuItem", back_populates="category")

class MenuItem(Base):
    __tablename__ = "menu_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    category_id = Column(UUID(as_uuid=True), ForeignKey('categories.id', ondelete='CASCADE'), nullable=False)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    price = Column(Float, nullable=False)
    cost_price = Column(Float, default=0.0)
    image_url = Column(String, nullable=True)
    SKU = Column(String, nullable=True)
    is_available = Column(Boolean, default=True)
    preparation_time_minutes = Column(Integer, default=15)
    tax_rate = Column(Float, default=0.0) # percentage (e.g. 8.0 for 8%)
    discount_rate = Column(Float, default=0.0) # percentage

    # Relationships
    restaurant = relationship("Restaurant", back_populates="menu_items")
    category = relationship("Category", back_populates="menu_items")
    variants = relationship("MenuItemVariant", back_populates="menu_item", cascade="all, delete-orphan")
    addons = relationship("MenuItemAddon", back_populates="menu_item", cascade="all, delete-orphan")
    order_items = relationship("OrderItem", back_populates="menu_item")

class MenuItemVariant(Base):
    __tablename__ = "menu_item_variants"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    menu_item_id = Column(UUID(as_uuid=True), ForeignKey('menu_items.id', ondelete='CASCADE'), nullable=False)
    name = Column(String, nullable=False) # e.g. "Large", "Regular"
    price_override = Column(Float, nullable=True)

    # Relationships
    menu_item = relationship("MenuItem", back_populates="variants")

class MenuItemAddon(Base):
    __tablename__ = "menu_item_addons"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    menu_item_id = Column(UUID(as_uuid=True), ForeignKey('menu_items.id', ondelete='CASCADE'), nullable=False)
    name = Column(String, nullable=False) # e.g. "Cheese", "Bacon"
    price = Column(Float, default=0.0)

    # Relationships
    menu_item = relationship("MenuItem", back_populates="addons")

class RestaurantTable(Base):
    __tablename__ = "tables"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    branch_id = Column(UUID(as_uuid=True), ForeignKey('branches.id', ondelete='CASCADE'), nullable=False)
    table_number = Column(String, nullable=False)
    capacity = Column(Integer, default=4)
    status = Column(String, default="available") # available, occupied, reserved, cleaning, disabled
    section = Column(String, default="Main Hall") # Main Hall, Terrace, VIP

    # Relationships
    restaurant = relationship("Restaurant", back_populates="tables")
    branch = relationship("Branch", back_populates="tables")
    orders = relationship("Order", back_populates="table")

class Order(Base):
    __tablename__ = "orders"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    branch_id = Column(UUID(as_uuid=True), ForeignKey('branches.id', ondelete='CASCADE'), nullable=False)
    table_id = Column(UUID(as_uuid=True), ForeignKey('tables.id', ondelete='SET NULL'), nullable=True)
    customer_id = Column(UUID(as_uuid=True), ForeignKey('customers.id', ondelete='SET NULL'), nullable=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='SET NULL'), nullable=True) # Cashier or Waiter
    order_number = Column(String, nullable=False)
    order_type = Column(String, default="dine_in") # dine_in, takeaway, delivery
    status = Column(String, default="pending") # pending, confirmed, preparing, ready, served, completed, cancelled
    notes = Column(String, nullable=True)
    subtotal = Column(Float, default=0.0)
    tax_amount = Column(Float, default=0.0)
    discount_amount = Column(Float, default=0.0)
    total_amount = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="orders")
    branch = relationship("Branch", back_populates="orders")
    table = relationship("RestaurantTable", back_populates="orders")
    customer = relationship("Customer", back_populates="orders")
    staff = relationship("User", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="order")

# Association for OrderItem <-> Addon
order_item_addons = Table(
    'order_item_addons',
    Base.metadata,
    Column('order_item_id', UUID(as_uuid=True), ForeignKey('order_items.id', ondelete='CASCADE'), primary_key=True),
    Column('addon_id', UUID(as_uuid=True), ForeignKey('menu_item_addons.id', ondelete='CASCADE'), primary_key=True)
)

class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_id = Column(UUID(as_uuid=True), ForeignKey('orders.id', ondelete='CASCADE'), nullable=False)
    menu_item_id = Column(UUID(as_uuid=True), ForeignKey('menu_items.id', ondelete='SET NULL'), nullable=True)
    quantity = Column(Integer, default=1)
    unit_price = Column(Float, nullable=False)
    notes = Column(String, nullable=True)
    selected_variant_id = Column(UUID(as_uuid=True), ForeignKey('menu_item_variants.id', ondelete='SET NULL'), nullable=True)

    # Relationships
    order = relationship("Order", back_populates="items")
    menu_item = relationship("MenuItem", back_populates="order_items")
    addons = relationship("MenuItemAddon", secondary=order_item_addons)

class Payment(Base):
    __tablename__ = "payments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    order_id = Column(UUID(as_uuid=True), ForeignKey('orders.id', ondelete='CASCADE'), nullable=False)
    payment_method = Column(String, default="cash") # cash, card, mobile, split
    amount = Column(Float, nullable=False)
    status = Column(String, default="pending") # pending, completed, failed
    transaction_id = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="payments")
    order = relationship("Order", back_populates="payments")

class Customer(Base):
    __tablename__ = "customers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    name = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    email = Column(String, nullable=True)
    address = Column(String, nullable=True)
    outstanding_balance = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="customers")
    orders = relationship("Order", back_populates="customer")

class InventoryItem(Base):
    __tablename__ = "inventory_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    name = Column(String, nullable=False)
    SKU = Column(String, nullable=True)
    unit = Column(String, default="pcs") # kg, liters, pcs, etc.
    current_stock = Column(Float, default=0.0)
    minimum_stock = Column(Float, default=0.0)
    cost = Column(Float, default=0.0)
    supplier_id = Column(UUID(as_uuid=True), ForeignKey('suppliers.id', ondelete='SET NULL'), nullable=True)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="inventory_items")
    supplier = relationship("Supplier", back_populates="inventory_items")
    transactions = relationship("InventoryTransaction", back_populates="inventory_item", cascade="all, delete-orphan")

class InventoryTransaction(Base):
    __tablename__ = "inventory_transactions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    inventory_item_id = Column(UUID(as_uuid=True), ForeignKey('inventory_items.id', ondelete='CASCADE'), nullable=False)
    type = Column(String, nullable=False) # in, out, adjustment, purchase
    quantity = Column(Float, nullable=False)
    reason = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    inventory_item = relationship("InventoryItem", back_populates="transactions")

class Supplier(Base):
    __tablename__ = "suppliers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    name = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    email = Column(String, nullable=True)
    address = Column(String, nullable=True)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="suppliers")
    inventory_items = relationship("InventoryItem", back_populates="supplier")

class Expense(Base):
    __tablename__ = "expenses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    category = Column(String, nullable=False) # rent, salary, utilities, ingredients, maintenance, marketing, other
    amount = Column(Float, nullable=False)
    date = Column(DateTime, default=datetime.utcnow)
    payment_method = Column(String, default="cash") # cash, card, bank_transfer
    description = Column(String, nullable=True)
    attachment_url = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="expenses")

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'), nullable=True) # Null for all users in restaurant
    title = Column(String, nullable=False)
    message = Column(String, nullable=False)
    type = Column(String, default="info") # info, low_stock, new_order, payment
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="notifications")
    user = relationship("User", back_populates="notifications")

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    action = Column(String, nullable=False)
    details = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    restaurant_id = Column(UUID(as_uuid=True), ForeignKey('restaurants.id', ondelete='CASCADE'), nullable=False)
    plan_id = Column(UUID(as_uuid=True), ForeignKey('subscription_plans.id', ondelete='CASCADE'), nullable=False)
    status = Column(String, default="active") # active, expired, trialing
    starts_at = Column(DateTime, default=datetime.utcnow)
    ends_at = Column(DateTime, nullable=False)

    # Relationships
    restaurant = relationship("Restaurant", back_populates="subscriptions")
    plan = relationship("SubscriptionPlan", back_populates="subscriptions")

class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False) # e.g. "Basic", "Pro", "Enterprise"
    price = Column(Float, nullable=False)
    max_branches = Column(Integer, default=1)
    max_users = Column(Integer, default=5)

    # Relationships
    subscriptions = relationship("Subscription", back_populates="plan")
