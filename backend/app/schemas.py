from pydantic import BaseModel, EmailStr, Field, model_validator
from typing import List, Optional, Union
from uuid import UUID
from datetime import datetime

# --- Auth Schemas ---
class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str

class TokenData(BaseModel):
    user_id: Optional[UUID] = None
    restaurant_id: Optional[UUID] = None
    permissions: List[str] = []

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserRegister(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    restaurant_name: str

class UserUpdate(BaseModel):
    full_name: str

class RestaurantUpdate(BaseModel):
    phone: Optional[str] = None

class UserResponse(BaseModel):
    id: UUID
    restaurant_id: UUID
    email: EmailStr
    full_name: str
    phone: Optional[str] = None
    status: str
    created_at: datetime
    permissions: List[str] = []
    role: Optional[str] = None

    model_config = {"from_attributes": True}

# --- Restaurant Schemas ---
class RestaurantResponse(BaseModel):
    id: UUID
    name: str
    logo_url: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    currency: str
    timezone: str
    is_active: bool

    model_config = {"from_attributes": True}

class RestaurantOnboarding(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    currency: str = "USD"
    timezone: str = "UTC"
    branch_name: str = "Main Branch"
    initial_categories: List[str] = []
    initial_tables: int = 5

# --- Branch Schemas ---
class BranchResponse(BaseModel):
    id: UUID
    name: str
    address: Optional[str] = None
    phone: Optional[str] = None

    class Config:
        from_attributes = True

# --- Menu Schemas ---
class CategoryCreate(BaseModel):
    name: str
    display_order: int = 0

class CategoryResponse(BaseModel):
    id: UUID
    name: str
    display_order: int

    class Config:
        from_attributes = True

class MenuItemVariantCreate(BaseModel):
    name: str
    price_override: Optional[float] = None

class MenuItemVariantResponse(BaseModel):
    id: UUID
    name: str
    price_override: Optional[float] = None

    class Config:
        from_attributes = True

class MenuItemAddonCreate(BaseModel):
    name: str
    price: float = 0.0

class MenuItemAddonResponse(BaseModel):
    id: UUID
    name: str
    price: float

    class Config:
        from_attributes = True

class MenuItemCreate(BaseModel):
    category_id: UUID
    name: str
    description: Optional[str] = None
    price: float
    cost_price: float = 0.0
    image_url: Optional[str] = None
    SKU: Optional[str] = None
    is_available: bool = True
    preparation_time_minutes: int = 15
    tax_rate: float = 0.0
    discount_rate: float = 0.0
    variants: List[MenuItemVariantCreate] = []
    addons: List[MenuItemAddonCreate] = []

class MenuItemResponse(BaseModel):
    id: UUID
    category_id: UUID
    name: str
    description: Optional[str] = None
    price: float
    cost_price: float
    image_url: Optional[str] = None
    SKU: Optional[str] = None
    is_available: bool
    preparation_time_minutes: int
    tax_rate: float
    discount_rate: float
    variants: List[MenuItemVariantResponse] = []
    addons: List[MenuItemAddonResponse] = []

    class Config:
        from_attributes = True

# --- Table Schemas ---
class TableCreate(BaseModel):
    branch_id: UUID
    table_number: str
    capacity: int = 4
    section: str = "Main Hall"

class TableResponse(BaseModel):
    id: UUID
    branch_id: UUID
    table_number: str
    capacity: int
    status: str
    section: str

    class Config:
        from_attributes = True

class TableStatusUpdate(BaseModel):
    status: str

# --- Order & POS Schemas ---
class OrderItemAddonCreate(BaseModel):
    addon_id: UUID

class OrderItemCreate(BaseModel):
    menu_item_id: UUID
    quantity: int = 1
    notes: Optional[str] = None
    selected_variant_id: Optional[UUID] = None
    addon_ids: List[UUID] = []

class OrderCreate(BaseModel):
    branch_id: UUID
    table_id: Optional[UUID] = None
    customer_id: Optional[UUID] = None
    order_type: str = "dine_in" # dine_in, takeaway, delivery
    notes: Optional[str] = None
    items: List[OrderItemCreate]
    discount_amount: float = 0.0

class OrderItemResponse(BaseModel):
    id: UUID
    menu_item_id: Optional[UUID] = None
    item_name: Optional[str] = None
    quantity: int
    unit_price: float
    notes: Optional[str] = None
    selected_variant_id: Optional[UUID] = None
    addons: List[MenuItemAddonResponse] = []

    @model_validator(mode='before')
    @classmethod
    def populate_item_name(cls, data):
        # When loading from ORM object, extract item name from menu_item relationship
        if hasattr(data, 'menu_item') and data.menu_item is not None:
            # Return a dict with item_name populated
            return {
                'id': data.id,
                'menu_item_id': data.menu_item_id,
                'item_name': data.menu_item.name,
                'quantity': data.quantity,
                'unit_price': data.unit_price,
                'notes': data.notes,
                'selected_variant_id': data.selected_variant_id,
                'addons': data.addons,
            }
        return data

    class Config:
        from_attributes = True

class OrderResponse(BaseModel):
    id: UUID
    restaurant_id: UUID
    branch_id: UUID
    table_id: Optional[UUID] = None
    customer_id: Optional[UUID] = None
    user_id: Optional[UUID] = None
    order_number: str
    order_type: str
    status: str
    notes: Optional[str] = None
    subtotal: float
    tax_amount: float
    discount_amount: float
    total_amount: float
    created_at: datetime
    updated_at: datetime
    items: List[OrderItemResponse] = []

    class Config:
        from_attributes = True

class OrderStatusUpdate(BaseModel):
    status: str

class PaymentCreate(BaseModel):
    payment_method: str # cash, card, mobile, split
    amount: float
    transaction_id: Optional[str] = None

class PaymentResponse(BaseModel):
    id: UUID
    order_id: UUID
    payment_method: str
    amount: float
    status: str
    transaction_id: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

# --- Customer & Supplier Schemas ---
class CustomerCreate(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None

class CustomerResponse(BaseModel):
    id: UUID
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    outstanding_balance: float
    created_at: datetime

    class Config:
        from_attributes = True

class SupplierCreate(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None

class SupplierResponse(BaseModel):
    id: UUID
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None

    class Config:
        from_attributes = True

# --- Inventory Schemas ---
class InventoryItemCreate(BaseModel):
    name: str
    SKU: Optional[str] = None
    unit: str = "pcs"
    current_stock: float = 0.0
    minimum_stock: float = 0.0
    cost: float = 0.0
    supplier_id: Optional[UUID] = None

class InventoryItemResponse(BaseModel):
    id: UUID
    name: str
    SKU: Optional[str] = None
    unit: str
    current_stock: float
    minimum_stock: float
    cost: float
    supplier_id: Optional[UUID] = None

    class Config:
        from_attributes = True

class InventoryTransactionCreate(BaseModel):
    inventory_item_id: UUID
    type: str # in, out, adjustment, purchase
    quantity: float
    reason: Optional[str] = None

class InventoryTransactionResponse(BaseModel):
    id: UUID
    inventory_item_id: UUID
    type: str
    quantity: float
    reason: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

# --- Expense Schemas ---
class ExpenseCreate(BaseModel):
    category: str
    amount: float
    payment_method: str = "cash"
    description: Optional[str] = None

class ExpenseResponse(BaseModel):
    id: UUID
    category: str
    amount: float
    date: datetime
    payment_method: str
    description: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

# --- Notification Schemas ---
class NotificationResponse(BaseModel):
    id: UUID
    title: str
    message: str
    type: str
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True

# --- Dashboard & Reports Schemas ---
class DashboardKPI(BaseModel):
    today_sales: float
    week_sales: float = 0.0
    month_sales: float = 0.0
    year_sales: float = 0.0
    orders_count: int
    avg_order_value: float
    today_expenses: float
    net_revenue: float

class DailySalesSeries(BaseModel):
    date: str
    amount: float

class MonthlySalesSeries(BaseModel):
    date: str
    amount: float

class YearlySalesSeries(BaseModel):
    date: str
    amount: float

class TopItemSeries(BaseModel):
    name: str
    quantity: int
    revenue: float

class DashboardSummary(BaseModel):
    kpi: DashboardKPI
    sales_chart: List[DailySalesSeries]
    top_items: List[TopItemSeries]
    recent_orders: List[OrderResponse]
    low_stock: List[InventoryItemResponse]
    recent_expenses: List[ExpenseResponse]

class PaymentMethodBreakdown(BaseModel):
    method: str
    amount: float
    percentage: float

class IncomeChartSeries(BaseModel):
    label: str
    date: str
    income: float
    orders_count: int

class CategoryRevenueSeries(BaseModel):
    name: str
    revenue: float
    percentage: float

class IncomeAnalyticsResponse(BaseModel):
    period: str # daily, weekly, monthly, yearly, custom
    total_income: float
    total_orders: int
    completed_orders: int
    cancelled_orders: int
    avg_order_value: float
    total_expenses: float
    net_profit: float
    payment_methods: List[PaymentMethodBreakdown]
    income_chart: List[IncomeChartSeries]
    top_items: List[TopItemSeries]
    revenue_by_category: List[CategoryRevenueSeries]

