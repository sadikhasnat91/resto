from sqlalchemy.orm import Session
from .database import engine, SessionLocal
from . import models
from .auth_utils import get_password_hash
from datetime import datetime, timedelta
import random

def seed_db(db: Session):
    # 1. Create Subscription Plans if not exists
    if db.query(models.SubscriptionPlan).count() == 0:
        plans = [
            models.SubscriptionPlan(name="Basic Starter", price=29.0, max_branches=1, max_users=3),
            models.SubscriptionPlan(name="Growth Pro", price=79.0, max_branches=3, max_users=15),
            models.SubscriptionPlan(name="Enterprise Elite", price=199.0, max_branches=10, max_users=100)
        ]
        db.add_all(plans)
        db.flush()

    # 2. Create Permissions
    perm_names = [
        ("pos:create", "Access POS checkout"),
        ("orders:view", "View and filter orders"),
        ("orders:update", "Update order status"),
        ("menu:edit", "Create, edit, delete menu items and categories"),
        ("inventory:edit", "Manage stock and adjust levels"),
        ("expenses:edit", "Log expenses"),
        ("reports:view", "View financial and performance reports"),
        ("staff:manage", "Manage restaurant users and permissions"),
        ("settings:edit", "Change restaurant profile and settings")
    ]
    
    db_perms = {}
    for name, desc in perm_names:
        perm = db.query(models.Permission).filter(models.Permission.name == name).first()
        if not perm:
            perm = models.Permission(name=name, description=desc)
            db.add(perm)
            db.flush()
        db_perms[name] = perm

    # 3. Create Global Roles (Owner, Manager, Cashier, Waiter, Kitchen)
    role_definitions = {
        "Owner": list(db_perms.keys()),
        "Manager": ["pos:create", "orders:view", "orders:update", "menu:edit", "inventory:edit", "expenses:edit", "reports:view", "staff:manage"],
        "Cashier": ["pos:create", "orders:view", "orders:update"],
        "Waiter": ["orders:view", "orders:update"],
        "Kitchen Staff": ["orders:view", "orders:update"]
    }

    db_roles = {}
    for r_name, p_names in role_definitions.items():
        role = db.query(models.Role).filter(models.Role.name == r_name, models.Role.restaurant_id == None).first()
        if not role:
            role = models.Role(name=r_name, description=f"Default global {r_name} role", is_custom=False)
            db.add(role)
            db.flush()
            # Link permissions
            for p_name in p_names:
                role.permissions.append(db_perms[p_name])
        db_roles[r_name] = role

    # 4. Check if we already have the demo restaurant seed
    demo_restaurant = db.query(models.Restaurant).filter(models.Restaurant.name == "Gourmet Bistro").first()
    if demo_restaurant:
        db.commit()
        return

    # Create Gourmet Bistro Restaurant
    restaurant = models.Restaurant(
        name="Gourmet Bistro",
        logo_url="https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=200",
        phone="+1234567890",
        email="info@gourmetbistro.com",
        address="123 Culinary Boulevard, Food Town",
        currency="USD",
        timezone="America/New_York"
    )
    db.add(restaurant)
    db.flush()

    # Link Subscription
    pro_plan = db.query(models.SubscriptionPlan).filter(models.SubscriptionPlan.name == "Growth Pro").first()
    sub = models.Subscription(
        restaurant_id=restaurant.id,
        plan_id=pro_plan.id,
        status="active",
        starts_at=datetime.utcnow(),
        ends_at=datetime.utcnow() + timedelta(days=365)
    )
    db.add(sub)

    # 5. Create Staff Users (Owner, Cashier, Waiter, Kitchen)
    owner_user = models.User(
        restaurant_id=restaurant.id,
        email="owner@restroflow.com",
        hashed_password=get_password_hash("password123"),
        full_name="Sarah Jenkins (Owner)",
        phone="+12015550192",
        status="active"
    )
    cashier_user = models.User(
        restaurant_id=restaurant.id,
        email="cashier@restroflow.com",
        hashed_password=get_password_hash("password123"),
        full_name="Alex Rivera (Cashier)",
        phone="+12015550193",
        status="active"
    )
    waiter_user = models.User(
        restaurant_id=restaurant.id,
        email="waiter@restroflow.com",
        hashed_password=get_password_hash("password123"),
        full_name="David Chen (Waiter)",
        phone="+12015550194",
        status="active"
    )
    kitchen_user = models.User(
        restaurant_id=restaurant.id,
        email="kitchen@restroflow.com",
        hashed_password=get_password_hash("password123"),
        full_name="Chef Marcus (Kitchen)",
        phone="+12015550195",
        status="active"
    )
    
    db.add_all([owner_user, cashier_user, waiter_user, kitchen_user])
    db.flush()

    # Assign Roles
    db.execute(models.user_roles.insert().values(user_id=owner_user.id, role_id=db_roles["Owner"].id))
    db.execute(models.user_roles.insert().values(user_id=cashier_user.id, role_id=db_roles["Cashier"].id))
    db.execute(models.user_roles.insert().values(user_id=waiter_user.id, role_id=db_roles["Waiter"].id))
    db.execute(models.user_roles.insert().values(user_id=kitchen_user.id, role_id=db_roles["Kitchen Staff"].id))

    # 6. Create Branches
    branch = models.Branch(
        restaurant_id=restaurant.id,
        name="Main Street Branch",
        address="123 Culinary Boulevard",
        phone="+1234567890"
    )
    db.add(branch)
    db.flush()

    # 7. Create Categories & Menu Items
    cat_starters = models.Category(restaurant_id=restaurant.id, name="Starters", display_order=0)
    cat_mains = models.Category(restaurant_id=restaurant.id, name="Mains", display_order=1)
    cat_desserts = models.Category(restaurant_id=restaurant.id, name="Desserts", display_order=2)
    cat_drinks = models.Category(restaurant_id=restaurant.id, name="Beverages", display_order=3)
    db.add_all([cat_starters, cat_mains, cat_desserts, cat_drinks])
    db.flush()

    # Add Menu Items
    # Wings
    wings = models.MenuItem(
        restaurant_id=restaurant.id, category_id=cat_starters.id,
        name="Buffalo Wings", description="Spicy chicken wings served with blue cheese dip",
        price=12.50, cost_price=4.20, SKU="STR-WING-01", tax_rate=8.0
    )
    db.add(wings)
    db.flush()
    # Addon/Variants for wings
    wings_mild = models.MenuItemVariant(menu_item_id=wings.id, name="Mild Sauce")
    wings_hot = models.MenuItemVariant(menu_item_id=wings.id, name="Extra Hot Sauce")
    wings_extra_dip = models.MenuItemAddon(menu_item_id=wings.id, name="Extra Dip", price=1.50)
    db.add_all([wings_mild, wings_hot, wings_extra_dip])

    # Burgers
    burger = models.MenuItem(
        restaurant_id=restaurant.id, category_id=cat_mains.id,
        name="Signature Truffle Burger", description="Angus beef patty, truffle mayo, swiss cheese, brioche bun",
        price=18.99, cost_price=6.50, SKU="MN-BURG-02", tax_rate=8.0
    )
    db.add(burger)
    db.flush()
    burger_single = models.MenuItemVariant(menu_item_id=burger.id, name="Single Patty")
    burger_double = models.MenuItemVariant(menu_item_id=burger.id, name="Double Patty", price_override=22.99)
    burger_cheese = models.MenuItemAddon(menu_item_id=burger.id, name="Extra Cheese", price=1.00)
    burger_bacon = models.MenuItemAddon(menu_item_id=burger.id, name="Smoked Bacon", price=2.00)
    db.add_all([burger_single, burger_double, burger_cheese, burger_bacon])

    # Pizza
    pizza = models.MenuItem(
        restaurant_id=restaurant.id, category_id=cat_mains.id,
        name="Artisanal Margherita Pizza", description="Fresh mozzarella, san marzano tomatoes, basil, extra virgin olive oil",
        price=15.99, cost_price=3.90, SKU="MN-PIZ-03", tax_rate=8.0
    )
    db.add(pizza)
    db.flush()
    pizza_med = models.MenuItemVariant(menu_item_id=pizza.id, name="12 inch Medium")
    pizza_lrg = models.MenuItemVariant(menu_item_id=pizza.id, name="16 inch Large", price_override=19.99)
    pizza_pepperoni = models.MenuItemAddon(menu_item_id=pizza.id, name="Add Pepperoni", price=2.50)
    db.add_all([pizza_med, pizza_lrg, pizza_pepperoni])

    # Desserts
    lava = models.MenuItem(
        restaurant_id=restaurant.id, category_id=cat_desserts.id,
        name="Chocolate Lava Cake", description="Warm chocolate cake with molten core, served with vanilla ice cream",
        price=8.99, cost_price=2.10, SKU="DES-LAVA-04", tax_rate=8.0
    )
    db.add(lava)
    db.flush()

    # Drinks
    lemonade = models.MenuItem(
        restaurant_id=restaurant.id, category_id=cat_drinks.id,
        name="Fresh Mint Lemonade", description="House-squeezed lemons with fresh mint and simple syrup",
        price=4.50, cost_price=0.80, SKU="DRK-LEM-05", tax_rate=8.0
    )
    db.add(lemonade)
    db.flush()

    # 8. Create Tables
    tables = []
    # Main Hall Tables
    for i in range(1, 7):
        tables.append(models.RestaurantTable(
            restaurant_id=restaurant.id, branch_id=branch.id,
            table_number=f"T-{i}", capacity=2 if i % 2 == 1 else 4,
            status="available" if i != 2 else "occupied", section="Main Hall"
        ))
    # Terrace Tables
    for i in range(7, 11):
        tables.append(models.RestaurantTable(
            restaurant_id=restaurant.id, branch_id=branch.id,
            table_number=f"Terrace-{i}", capacity=4 if i % 2 == 0 else 6,
            status="available" if i != 8 else "reserved", section="Terrace"
        ))
    db.add_all(tables)
    db.flush()

    # 9. Create Customers & Suppliers
    customer1 = models.Customer(restaurant_id=restaurant.id, name="Jane Miller", email="jane.m@gmail.com", phone="+1555123456", outstanding_balance=0.0)
    customer2 = models.Customer(restaurant_id=restaurant.id, name="John Carter", email="jcarter@hotmail.com", phone="+1555987654", outstanding_balance=12.50)
    db.add_all([customer1, customer2])
    db.flush()

    supplier = models.Supplier(restaurant_id=restaurant.id, name="Bistro Wholesalers Inc.", email="sales@bistrowholesale.com", phone="+18005558899", address="45 Warehouse Ave, Logistics Center")
    db.add(supplier)
    db.flush()

    # 10. Create Inventory Items & Transactions
    inv_patty = models.InventoryItem(restaurant_id=restaurant.id, name="Angus Beef Patties (8oz)", SKU="INV-BEEF-01", unit="pcs", current_stock=120.0, minimum_stock=50.0, cost=2.50, supplier_id=supplier.id)
    inv_buns = models.InventoryItem(restaurant_id=restaurant.id, name="Brioche Burger Buns", SKU="INV-BUNS-02", unit="pcs", current_stock=150.0, minimum_stock=40.0, cost=0.50, supplier_id=supplier.id)
    inv_cheese = models.InventoryItem(restaurant_id=restaurant.id, name="Swiss Cheese Slices", SKU="INV-CHSE-03", unit="pcs", current_stock=200.0, minimum_stock=30.0, cost=0.20, supplier_id=supplier.id)
    inv_tomatoes = models.InventoryItem(restaurant_id=restaurant.id, name="Roma Tomatoes", SKU="INV-TOM-04", unit="kg", current_stock=5.0, minimum_stock=10.0, cost=3.00, supplier_id=supplier.id) # Low stock
    db.add_all([inv_patty, inv_buns, inv_cheese, inv_tomatoes])
    db.flush()

    # Inventory transactions
    db.add_all([
        models.InventoryTransaction(restaurant_id=restaurant.id, inventory_item_id=inv_patty.id, type="in", quantity=150.0, reason="Initial stock delivery"),
        models.InventoryTransaction(restaurant_id=restaurant.id, inventory_item_id=inv_patty.id, type="out", quantity=30.0, reason="Kitchen usage"),
        models.InventoryTransaction(restaurant_id=restaurant.id, inventory_item_id=inv_tomatoes.id, type="in", quantity=15.0, reason="Supplier purchase"),
        models.InventoryTransaction(restaurant_id=restaurant.id, inventory_item_id=inv_tomatoes.id, type="out", quantity=10.0, reason="Spoilage adjustment")
    ])

    # 11. Create Historical Expenses
    db.add_all([
        models.Expense(restaurant_id=restaurant.id, category="rent", amount=2500.0, date=datetime.utcnow() - timedelta(days=20), payment_method="bank_transfer", description="Monthly Rent for Main Branch"),
        models.Expense(restaurant_id=restaurant.id, category="ingredients", amount=450.0, date=datetime.utcnow() - timedelta(days=10), payment_method="card", description="Weekly grocery replenishment"),
        models.Expense(restaurant_id=restaurant.id, category="utilities", amount=320.0, date=datetime.utcnow() - timedelta(days=5), payment_method="bank_transfer", description="Electricity bill"),
        models.Expense(restaurant_id=restaurant.id, category="marketing", amount=150.0, date=datetime.utcnow(), payment_method="card", description="Instagram local ads boost")
    ])

    # 12. Create Sales Orders History (Last 7 Days)
    t2_table = [t for t in tables if t.table_number == "T-2"][0]
    # Today's complete order
    order_today = models.Order(
        restaurant_id=restaurant.id, branch_id=branch.id, table_id=t2_table.id, customer_id=customer1.id,
        user_id=cashier_user.id, order_number="ORD-260825-0001", order_type="dine_in", status="completed",
        notes="Allergies: None. Medium rare burger.", subtotal=38.48, tax_amount=3.08, discount_amount=2.00, total_amount=39.56,
        created_at=datetime.utcnow() - timedelta(hours=2)
    )
    db.add(order_today)
    db.flush()

    # Add items to order
    item1 = models.OrderItem(order_id=order_today.id, menu_item_id=burger.id, quantity=1, unit_price=18.99, selected_variant_id=burger_single.id)
    db.add(item1)
    db.flush()
    db.execute(models.order_item_addons.insert().values(order_item_id=item1.id, addon_id=burger_bacon.id)) # bacon +2.00

    item2 = models.OrderItem(order_id=order_today.id, menu_item_id=wings.id, quantity=1, unit_price=12.50, selected_variant_id=wings_mild.id)
    db.add(item2)
    db.flush()

    item3 = models.OrderItem(order_id=order_today.id, menu_item_id=lemonade.id, quantity=1, unit_price=4.50)
    db.add(item3)
    db.flush()

    # Add payment
    payment_today = models.Payment(
        restaurant_id=restaurant.id, order_id=order_today.id,
        payment_method="card", amount=39.56, status="completed",
        transaction_id="TX_GUR_991823"
    )
    db.add(payment_today)

    # Historical completed orders for charts (last 6 days)
    for i in range(1, 7):
        hist_time = datetime.utcnow() - timedelta(days=i, hours=random.randint(1, 8))
        subt = random.uniform(25.00, 110.00)
        tax = subt * 0.08
        disc = random.choice([0.0, 5.0, 10.0])
        tot = (subt + tax) - disc

        hist_order = models.Order(
            restaurant_id=restaurant.id, branch_id=branch.id, table_id=None, customer_id=random.choice([customer1.id, customer2.id, None]),
            user_id=cashier_user.id, order_number=f"ORD-{(hist_time).strftime('%y%m%d')}-000{i}", order_type="takeaway", status="completed",
            subtotal=round(subt, 2), tax_amount=round(tax, 2), discount_amount=disc, total_amount=round(tot, 2),
            created_at=hist_time
        )
        db.add(hist_order)
        db.flush()

        # Add generic item link for statistics
        hist_item = models.OrderItem(order_id=hist_order.id, menu_item_id=burger.id, quantity=random.randint(1, 3), unit_price=18.99)
        db.add(hist_item)

        hist_payment = models.Payment(
            restaurant_id=restaurant.id, order_id=hist_order.id,
            payment_method=random.choice(["cash", "card", "mobile"]), amount=round(tot, 2), status="completed",
            created_at=hist_time
        )
        db.add(hist_payment)

    # 13. Create Kitchen Pending Order for display demonstration
    t3_table = [t for t in tables if t.table_number == "T-3"][0]
    order_pending = models.Order(
        restaurant_id=restaurant.id, branch_id=branch.id, table_id=t3_table.id, customer_id=None,
        user_id=waiter_user.id, order_number="ORD-260825-0002", order_type="dine_in", status="preparing",
        notes="No onions on the pizza.", subtotal=20.49, tax_amount=1.64, discount_amount=0.0, total_amount=22.13,
        created_at=datetime.utcnow() - timedelta(minutes=15)
    )
    db.add(order_pending)
    db.flush()

    p_item = models.OrderItem(order_id=order_pending.id, menu_item_id=pizza.id, quantity=1, unit_price=15.99, selected_variant_id=pizza_med.id)
    db.add(p_item)
    db.flush()
    db.execute(models.order_item_addons.insert().values(order_item_id=p_item.id, addon_id=pizza_pepperoni.id))

    p_item2 = models.OrderItem(order_id=order_pending.id, menu_item_id=lemonade.id, quantity=1, unit_price=4.50)
    db.add(p_item2)

    # 14. Create Low Stock Notification
    notif = models.Notification(
        restaurant_id=restaurant.id, user_id=None,
        title="Low Stock Alert", message=f"Item '{inv_tomatoes.name}' has fallen below the minimum stock limit of {inv_tomatoes.minimum_stock} {inv_tomatoes.unit}.",
        type="low_stock", is_read=False
    )
    db.add(notif)

    db.commit()

def seed():
    db = SessionLocal()
    try:
        seed_db(db)
    finally:
        db.close()
