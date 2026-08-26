# RestroFlow — Restaurant Management & POS SaaS System

[![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python)](https://python.org)
[![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL%2FSQLite-4169E1?logo=postgresql)](https://www.postgresql.org)
[![Docker](https://img.shields.io/badge/Deployment-Docker-2496ED?logo=docker)](https://www.docker.com)

**RestroFlow** is a modern, full-stack, multi-tenant Restaurant Management System & Point of Sale (POS) application built for single and multi-branch restaurants. It features real-time kitchen broadcasts, comprehensive financial & income reporting, inventory tracking, role-based staff permissions, and table management.

---

## 🌟 Features Overview

### 1. 🍽️ Point of Sale (POS) & Order Management
- **Fast POS Interface**: Quick item selection, variants, add-ons, and real-time cart calculations.
- **Order History & Search**: Instant search by Order #, filter by status (`Pending`, `Preparing`, `Ready`, `Completed`, `Cancelled`), and inspect full digital receipts.
- **Order Types**: Dine-in, Takeaway, and Delivery orders.

### 2. 👨‍🍳 Kitchen Display System (KDS)
- **Real-Time WebSockets**: Live order updates instantly broadcasted to kitchen screens without page refreshes.
- **Status Lifecycle**: Transition orders from `Pending` ➔ `Preparing` ➔ `Ready` ➔ `Completed`.

### 3. 📈 Income Analytics & Reports
- **Multi-Period Filtering**: Instant switching between **Daily**, **Weekly**, **Monthly**, and **Yearly** income views.
- **Financial KPIs**: Gross Revenue, Completed Order Count, Average Order Value, Total Expenses, and Net Profit.
- **Dynamic Trend Graphs**: Smooth visual line charts representing income fluctuations over hours, days, or months.
- **Payment Method Breakdown**: Visual progress bars and analytics for Cash, Card, Mobile Banking, and Split payments.
- **Top Sellers & Category Distribution**: Identify best-performing items and category revenue percentages.

### 4. 🪑 Floor Plan & Table Management
- Interactive table layout, status management (`Available`, `Occupied`, `Reserved`, `Cleaning`), and quick bill assignment.

### 5. 📦 Inventory & Stock Control
- Real-time stock level tracking, cost price auditing, and minimum stock alerts for automatic reordering.

### 6. 👥 Staff & Role-Based Access Control (RBAC)
- Multi-user support with custom permissions (`pos:create`, `orders:view`, `menu:edit`, `inventory:edit`, `reports:view`, `staff:manage`, etc.).

---

## 🏗️ Architecture & Technology Stack

| Component | Technology | Description |
|---|---|---|
| **Frontend** | **Flutter Web & Desktop** | State management via `flutter_riverpod`, routing via `go_router`, charts via `fl_chart`, HTTP client via `dio`. |
| **Backend** | **Python (FastAPI)** | High-performance async REST APIs, JWT authentication, WebSockets, SQLAlchemy ORM, and Pydantic schemas. |
| **Database** | **SQLite / PostgreSQL** | Relational data model supporting multi-tenant isolation, orders, inventory, and analytics. |
| **Containerization** | **Docker & Docker Compose** | Multi-container setup with PostgreSQL service. |

---

## 📁 Repository Structure

```
resto/
├── backend/                  # FastAPI Python Backend
│   ├── app/
│   │   ├── routers/          # API Route Controllers (auth, pos, orders, reports, etc.)
│   │   ├── models.py         # SQLAlchemy Database Models
│   │   ├── schemas.py        # Pydantic Schemas & Data Transfer Objects
│   │   ├── crud.py           # Database Queries & Analytics Logic
│   │   ├── websocket.py      # Real-time WebSocket Broadcaster
│   │   ├── database.py       # DB Connection Engine
│   │   ├── main.py           # FastAPI Application Entry Point
│   │   └── seed.py           # Initial Database Seeder
│   ├── requirements.txt      # Python Dependencies
│   └── Dockerfile
│
├── frontend/                 # Flutter Web / Desktop Application
│   ├── lib/
│   │   ├── core/             # Theme, Dio Client, Routing, Shared Widgets
│   │   └── features/         # Modular Feature Modules
│   │       ├── auth/         # Login & Register Screens
│   │       ├── pos/          # POS Checkout Interface
│   │       ├── kitchen/      # Kitchen Display System (KDS)
│   │       ├── orders/       # Order History & Receipts
│   │       ├── reports/      # Daily, Weekly, Monthly, Yearly Income Analytics
│   │       ├── tables/       # Table Floor Plan
│   │       ├── menu/         # Menu & Addons Manager
│   │       ├── inventory/    # Stock Management
│   │       ├── expenses/     # Operational Expenses Log
│   │       └── settings/     # Restaurant & Profile Settings
│   └── pubspec.yaml          # Flutter Dependencies
│
├── docker-compose.yml        # Docker Orchestration Configuration
└── README.md                 # Project Documentation
```

---

## 🚀 Getting Started

### Prerequisites
- **Python**: 3.9 or higher
- **Flutter SDK**: 3.19 or higher
- **Git**

---

### 1. Backend Setup (FastAPI)

1. **Navigate to the backend directory**:
   ```bash
   cd backend
   ```

2. **Create and activate a virtual environment**:
   - **Windows (PowerShell)**:
     ```powershell
     python -m venv venv
     .\venv\Scripts\Activate.ps1
     ```
   - **macOS / Linux**:
     ```bash
     python3 -m venv venv
     source venv/bin/activate
     ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Run the FastAPI server**:
   ```bash
   python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
   ```

   - **API Docs**: Open `http://127.0.0.1:8000/docs` in your browser for Swagger UI.

---

### 2. Frontend Setup (Flutter)

1. **Navigate to the frontend directory**:
   ```bash
   cd frontend
   ```

2. **Get Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app in Chrome**:
   ```bash
   flutter run -d chrome
   ```

---

## 🔑 Default Credentials (Seed Data)

Upon initial launch, the system automatically seeds default demo data:

| Field | Value |
|---|---|
| **Role** | Restaurant Owner |
| **Email** | `owner@restroflow.com` |
| **Password** | `password123` |

---

## 🐳 Running with Docker

To run PostgreSQL and the backend using Docker Compose:

```bash
docker-compose up --build -d
```

---

## 📄 License

This project is open-source under the MIT License.
