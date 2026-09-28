# MCQ App — Complete Application Flow

## 1. App Entry & Startup

**`main.dart`** → **`app.dart` (McqApp)**

1. Firebase init (optional) + FCM push notification setup
2. Restore theme from `SharedPreferences` (`themeModeProvider`)
3. Restore auth session from `SharedPreferences` (token + user JSON)
4. `McqApp` watches `authControllerProvider` to decide the home screen:
   - `AuthStatus.initial` → `SplashScreen` (logo fade-in while session restores)
   - `AuthStatus.authenticating` → `LoginScreen`
   - `AuthStatus.authenticated` → `HomeShell`
   - `AuthStatus.unauthenticated` → `LoginScreen`

**No named routes.** All navigation is imperative (`Navigator.push(MaterialPageRoute(...))`).

---

## 2. Authentication Flow

### Login
1. User enters email → debounced preview (450ms) → `GET /auth/preview?email=...`
   - Returns: `{exists, role, name, shops[]}`
   - If **manager**: shows shop dropdown
2. User enters password → taps "Sign In" → `POST /auth/login` with `{email, password, shopId?, fcmToken?}`
3. On success: saves token + user to `SharedPreferences` → state becomes `authenticated` → navigates to `HomeShell`
4. "Remember me" persists email in `SharedPreferences`

### Logout
- From **Drawer** or **ProfileScreen**: confirmation dialog → `POST /auth/logout` (best-effort) → clear session → state becomes `unauthenticated`
- **Force logout** on 401: `ApiClient` interceptor detects 401 → clears session automatically

### Session Restore
- On app start: reads token + user from `SharedPreferences`
- If valid → `authenticated` → `HomeShell`
- If missing → `unauthenticated` → `LoginScreen`

---

## 3. Navigation Structure

### HomeShell (`home_shell.dart`)
- `Scaffold` with `IndexedStack` (keeps screens alive in memory via `_cache`)
- **Bottom Navigation Bar** (floating glass bar, gold active pill):
  - Admin: Dashboard | Inventory | Sales | Reports | Profile
  - Manager: Dashboard | Inventory | Profile
- **Drawer** (admin-only items marked with *):

| Item | Admin | Manager | Opens |
|---|---|---|---|
| Dashboard | ✓ | ✓ | Tab switch |
| Inventory | ✓ | ✓ | Tab switch |
| Sales | ✓ | ✗ | Tab switch |
| Reports | ✓ | ✗ | Tab switch |
| Products | ✓ | ✓ | Full-page push |
| Expenses | ✓ | ✓ | Full-page push |
| Analytics | ✓ | ✗ | Full-page push |
| Categories | ✓ | ✗ | Full-page push |
| Shops | ✓ | ✗ | Full-page push |
| Managers | ✓ | ✗ | Full-page push |
| Audit Logs | ✓ | ✗ | Full-page push |
| Notifications | ✓ | ✓ | Full-page push |
| Settings | ✓ | ✓ | Full-page push |
| Logout | ✓ | ✓ | Dialog → clear session |

Full-page pushes call `dashboardControllerProvider.notifier.refresh()` on pop.

---

## 4. Screen-by-Screen Reference

### 4.1 Dashboard (`features/dashboard/presentation/dashboard_screen.dart`)
- **Both roles** (different views)
- **Provider:** `dashboardControllerProvider`
- **Admin view:** Header (muallim logo, MUALLIM CARPETS brand, bell with unread count, avatar → ProfileScreen), Revenue Overview card (animated number, growth badge, sparkline chart), 4 stat tiles (Revenue/Profit/Sales/Expenses), Branch Overview (branch cards with Revenue/Profit/Sales + "Open Branch" → `ShopDetailScreen`), Manager Logs → `AuditLogsScreen`
- **Manager view:** Same header + revenue + stat tiles, single branch card, Quick Actions row (Add Product, New Sale, Stock Transfer, Expense Entry), Analytics (weekly sales bar, monthly profit line, top products)
- Background: `admin_dashboard.jfif` (subtle transparent showroom image)

### 4.2 Shop Detail (`features/dashboard/presentation/shop_detail_screen.dart`)
- **Both roles** (reached from branch cards on dashboard)
- **Provider:** `shopDetailProvider(shopId)` (FutureProvider.family)
- Shows: shop header, revenue/profit/sales stat cards, daily sales chart, monthly revenue chart, expense pie chart, top products, recent activity

### 4.3 Inventory (`features/inventory/presentation/inventory_screen.dart`)
- **Both roles** (bottom nav tab)
- **Provider:** `inventoryHistoryControllerProvider`
- Features: search bar (by product/supplier), filter by action type (All/Stock In/Stock Out via PopupMenu), low stock button → `LowStockScreen`, stock out FAB → `StockOutScreen`

### 4.4 Stock In (`features/inventory/presentation/stock_screens.dart` — `StockInScreen`)
- **Both roles**
- **Provider:** `stockMutationControllerProvider`
- Form: select product, quantity, supplier, notes
- On success: invalidates inventory, products, dashboard

### 4.5 Stock Out (`features/inventory/presentation/stock_screens.dart` — `StockOutScreen`)
- **Both roles**
- **Provider:** `stockMutationControllerProvider`
- Form: select product, quantity, reason, notes
- On success: invalidates inventory, products, dashboard

### 4.6 Low Stock (`features/inventory/presentation/stock_screens.dart` — `LowStockScreen`)
- **Both roles**
- Lists products where quantity ≤ lowStockThreshold
- "Restock" button → `StockInScreen`

### 4.7 Sales List (`features/sales/presentation/sales_list_screen.dart`)
- **Admin only** (bottom nav tab)
- **Provider:** `saleListControllerProvider`
- Features: date range filter (gold filter bar with clear), refresh, tap → `SaleDetailScreen`, delete with restock option (admin only)
- Filter: `showDateRangePicker` → passes `from`/`to` to backend `GET /sales?from=...&to=...`

### 4.8 Sale Detail (`features/sales/presentation/sales_list_screen.dart` — `SaleDetailScreen`)
- **Both roles** (reached from sales list)
- Shows: customer info, shop, payment method, profit, line items, subtotal/discount/total, notes

### 4.9 Sale Form (`features/sales/presentation/sale_form_screen.dart`)
- **Both roles** (manager via dashboard quick actions; admin not via dashboard)
- **Provider:** `saleMutationControllerProvider`
- Form: customer name/phone, payment method, shop selector (admin if >1 shop), product selector with cart, quantity +/-, discount, notes
- On success: invalidates saleList, inventory, products, dashboard

### 4.10 Products List (`features/products/presentation/product_list_screen.dart`)
- **Both roles** (via drawer)
- **Provider:** `productListControllerProvider`
- Features: search (by name/SKU/barcode), category filter chips, low stock toggle, add/edit/delete, stock in per product

### 4.11 Product Form (`features/products/presentation/product_form_screen.dart`)
- **Both roles**
- **Provider:** `productMutationControllerProvider`
- Create/edit: name, SKU, barcode, category, brand, supplier, cost/selling price, quantity (create only), low stock threshold, description
- On success: invalidates productList, dashboard

### 4.12 Expenses List (`features/expenses/presentation/expense_list_screen.dart`)
- **Both roles** (via drawer). Delete only if admin.
- **Provider:** `expenseListControllerProvider`
- Features: add expense → `ExpenseFormScreen`, delete (admin only)

### 4.13 Expense Form (`features/expenses/presentation/expense_form_screen.dart`)
- **Both roles**
- **Provider:** `expenseMutationControllerProvider`
- Form: category dropdown (rent/electricity/salary/etc.), amount, date, description, shop selector (admin)
- On success: invalidates expenseList, dashboard

### 4.14 Reports (`features/reports/presentation/reports_screen.dart`)
- **Admin only** (bottom nav + drawer)
- **Provider:** `reportControllerProvider`
- Period selector (Today/Week/Month/Year)
- Summary grid (sales/expenses/profit/products/stock value/transactions)
- Sales report card, expense report card, inventory report card
- CSV export buttons for sales, expenses, inventory, audit logs

### 4.15 Analytics (`features/analytics/presentation/analytics_screen.dart`)
- **Admin only** (drawer)
- **Provider:** `analyticsControllerProvider`
- Charts: daily/weekly/monthly/yearly sales, expense breakdown pie, shop comparison table

### 4.16 Categories (`features/categories/presentation/category_screen.dart`)
- **Admin only** (drawer)
- **Provider:** `categoryListControllerProvider`, `categoryMutationControllerProvider`
- CRUD categories (name + description)

### 4.17 Shops (`features/shops/presentation/shops_screen.dart`)
- **Admin only** (drawer)
- **Provider:** `shopListControllerProvider`
- List/add/edit/delete shops. Manager dropdown fetched from `authRepositoryProvider.listManagers()`

### 4.18 Managers (`features/managers/presentation/managers_screen.dart`)
- **Admin only** (drawer)
- Uses `authRepositoryProvider.listManagers()` directly (FutureBuilder)
- Add/edit managers (name, email, phone, password, assigned shop)

### 4.19 Audit Logs (`features/audit/presentation/audit_logs_screen.dart`)
- **Admin only** (drawer + dashboard "View All")
- **Provider:** `auditControllerProvider`
- Paginated logs with stats bar, filter by module + action type
- Tap → `AuditDetailScreen` (full detail, old/new data, "Restore Record" for deletes)
- **Provider for detail:** `auditDetailControllerProvider`

### 4.20 Notifications (`features/notifications/presentation/notifications_screen.dart`)
- **Both roles** (drawer + dashboard bell)
- **Provider:** `notificationControllerProvider`, `unreadCountProvider`
- List with unread highlights, tap → mark read, mark all read, delete

### 4.21 Profile (`features/settings/presentation/profile_screen.dart`)
- **Both roles** (bottom nav tab for manager; bottom nav + drawer + dashboard avatar for admin)
- Shows avatar, name, role/shop
- Edit name/phone, change password, logout → `SettingsScreen`

### 4.22 Settings (`features/settings/presentation/settings_screen.dart`)
- **Both roles** (via drawer + profile)
- Theme selector (Light/Dark/System), About card

---

## 5. Data Flow Pattern

```
Screen (ConsumerWidget / ConsumerStatefulWidget)
  → watches a Controller Provider (NotifierProvider<XxxController, XxxState>)
    → reads a Repository Provider (Provider<XxxRepository>)
      → uses ApiClient (Provider<ApiClient> + Dio)
        → HTTP request with Bearer token header
          → Backend Express route + controller → Mongoose model
            → Response { success: true, data: {...} }
          ← Parsed model object
        ← Repository returns typed result
      ← Controller updates state (AsyncValue.data / AsyncValue.error)
    ← Screen rebuilds via ref.watch()
```

### Mutation + Invalidation Pattern
After every create/update/delete, the mutation controller calls `ref.invalidate(...)` on related list/dashboard providers → triggers re-fetch → screen rebuilds with fresh data.

---

## 6. API Layer

### Configuration
- **Base URL:** `http://10.0.2.2:5000/api` (Android emulator → host machine)
- **Auth:** Bearer token in `Authorization` header (auto-injected by interceptor)
- **Headers:** `x-platform`, `x-app-version`
- **Timeouts:** Connect 20s, Receive 30s

### Backend Stack
- **Server:** Node.js + Express.js
- **Database:** MongoDB (Mongoose ODM)
- **Auth:** JWT tokens

### Key Endpoints

| Domain | Endpoints | Query Params |
|---|---|---|
| Auth | `POST /auth/login`, `POST /auth/logout`, `GET /auth/preview`, `GET/PUT /auth/profile`, `PUT /auth/change-password`, `GET/POST/PUT /auth/managers` | |
| Dashboard | `GET /dashboard` | `shopId` |
| Shops | `GET/POST /shops`, `PUT/DELETE /shops/:id` | |
| Categories | `GET/POST /categories`, `PUT/DELETE /categories/:id` | |
| Products | `GET/POST /products`, `PUT/DELETE /products/:id`, `GET /products/low-stock` | `search`, `categoryId`, `lowStock` |
| Inventory | `GET /inventory/history`, `POST /inventory/in`, `POST /inventory/out` | `actionType`, `productId`, `from`, `to`, `page`, `limit` |
| Sales | `GET/POST /sales`, `PUT/DELETE /sales/:id` | `shopId`, `from`, `to`, `page`, `limit` |
| Expenses | `GET/POST /expenses`, `PUT/DELETE /expenses/:id` | `shopId`, `from`, `to`, `category`, `page`, `limit` |
| Reports | `GET /reports`, `GET /reports/sales`, `GET /reports/expenses`, `GET /reports/inventory` | `period` (today/week/month/year), `shopId` |
| Analytics | `GET /analytics` | `shopId` |
| Audit | `GET /audit`, `GET /audit/:id`, `POST /audit/:id/restore` | `from`, `to`, `module`, `actionType`, `page`, `limit` |
| Notifications | `GET /notifications`, `PUT /notifications/read-all`, `PUT /notifications/:id/read`, `DELETE /notifications/:id` | |
| Export | `GET /reports/export`, `GET /audit/export` | `type` (sales/expenses/inventory/audit), `period` |

---

## 7. State Management (Riverpod)

### Provider Hierarchy
```
Screen
  → Controller Provider (NotifierProvider)  — holds UI state + AsyncValue
    → Repository Provider (Provider)        — data access layer
      → ApiClient Provider (Provider)       — HTTP client with auth interceptor
```

### Naming Convention
| Type | Suffix | Example |
|---|---|---|
| Repository | `RepositoryProvider` | `saleRepositoryProvider` |
| List Controller | `ListControllerProvider` | `saleListControllerProvider` |
| Mutation Controller | `MutationControllerProvider` | `saleMutationControllerProvider` |
| Derived | `Provider` | `currentUserProvider` |
| Parameterized | `Provider.family` | `shopDetailProvider` |

### Key Provider List

| Domain | List Provider | Mutation Provider |
|---|---|---|
| Auth | `authControllerProvider` | — |
| Dashboard | `dashboardControllerProvider` | — |
| Products | `productListControllerProvider` | `productMutationControllerProvider` |
| Inventory | `inventoryHistoryControllerProvider` | `stockMutationControllerProvider` |
| Sales | `saleListControllerProvider` | `saleMutationControllerProvider` |
| Expenses | `expenseListControllerProvider` | `expenseMutationControllerProvider` |
| Categories | `categoryListControllerProvider` | `categoryMutationControllerProvider` |
| Shops | `shopListControllerProvider` | — |
| Reports | `reportControllerProvider` | — |
| Analytics | `analyticsControllerProvider` | — |
| Audit | `auditControllerProvider` | — |
| Notifications | `notificationControllerProvider` | — |
| Settings | `themeModeProvider` | — |

### Invalidation Map (what refreshes after a mutation)
| Mutation | Providers Invalidated |
|---|---|
| Create/Edit/Delete Product | `productList`, `dashboard` |
| Stock In/Out | `inventoryHistory`, `productList`, `dashboard` |
| Create/Delete Sale | `saleList`, `inventoryHistory`, `productList`, `dashboard` |
| Create/Delete Expense | `expenseList`, `dashboard` |
| Create/Edit/Delete Shop | `shopList`, `dashboard` |
| Create/Edit/Delete Category | `categoryList` |

---

## 8. Role-Based Access Summary

### Admin (full access)
- All screens and features
- Quick Actions removed from dashboard (admin is view-only)
- Analytics + Top Products removed from dashboard
- Stock In (+) removed from Inventory
- New Sale (+) removed from Sales
- Delete operations on sales, expenses, products
- Shop/Manager/Category CRUD
- Audit log restore
- CSV exports including audit logs

### Manager (branch-scoped)
- Dashboard with: revenue, stats, single branch card, Quick Actions (Add Product, New Sale, Stock Transfer, Expense Entry), Weekly Sales chart, Monthly Profit chart, Top Products
- Inventory (search + stock out only)
- Profile, Notifications, Settings, Products, Expenses
- Cannot access: Sales list, Reports, Analytics, Categories, Shops, Managers, Audit Logs
- Shop-scoped data (backend enforces via `assignedShop`)

---

## 9. File Tree

```
mobile/lib/
├── main.dart                              # Entry point
├── app.dart                               # McqApp root (auth switch)
├── shell/
│   └── home_shell.dart                    # IndexedStack + Drawer + BottomNav
├── core/
│   ├── api/
│   │   ├── api_client.dart                # Dio HTTP client + auth interceptor
│   │   └── api_exception.dart             # Custom exception
│   ├── constants/
│   │   ├── app_constants.dart             # baseUrl, enums, labels
│   │   └── api_endpoints.dart             # Centralized endpoint builder
│   ├── providers/
│   │   └── repository_providers.dart      # All 12 repository providers
│   ├── storage/
│   │   └── local_store.dart               # SharedPreferences wrapper
│   ├── theme/
│   │   ├── app_theme.dart                 # Light/dark ThemeData
│   │   └── app_colors.dart                # Colors + gradients
│   ├── utils/
│   │   ├── validators.dart                # Form validators
│   │   └── formatters.dart                # Currency/date formatters
│   ├── widgets/                           # Reusable UI components
│   └── services/
│       └── fcm_service.dart               # Firebase push notifications
└── features/
    ├── auth/                              # Login, session, user model
    ├── dashboard/                         # Dashboard + shop detail
    ├── inventory/                         # Stock in/out, history, low stock
    ├── sales/                             # Sales list, form, detail
    ├── products/                          # Product list + form
    ├── expenses/                          # Expense list + form
    ├── categories/                        # Category CRUD
    ├── shops/                             # Shop CRUD
    ├── managers/                          # Manager CRUD
    ├── audit/                             # Audit logs + detail + restore
    ├── notifications/                     # Push notification list
    ├── reports/                           # Period reports + CSV export
    ├── analytics/                         # Visual charts
    └── settings/                          # Profile + settings
```

---

## 10. Backend Structure

```
backend/src/
├── server.js                              # Express server entry
├── config/
│   ├── index.js                           # Port, DB URI, JWT secret, passwords
│   └── db.js                              # MongoDB connection
├── routes/
│   └── index.js                           # All route definitions + middleware
├── controllers/                           # Route handlers (12 controllers)
├── models/                                # Mongoose schemas (9 models)
├── middleware/
│   ├── auth.js                            # protect, restrictTo, scopedShop, recordAudit
│   └── errorHandler.js                    # 404 + global error handler
└── utils/
    ├── jwt.js                             # Token verification
    ├── ApiError.js                        # Custom error class
    ├── ApiResponse.js                     # Standardized response
    ├── asyncHandler.js                    # Async route wrapper
    └── stats.js                           # Stats calculations
```

### Mongoose Models
| Model | Key Fields |
|---|---|
| User | name, email, password, role (admin/manager), assignedShop, fcmToken |
| Shop | name, address, contactNumber, manager (ref User) |
| Category | name, description |
| Product | name, sku, barcode, category, brand, supplier, costPrice, sellingPrice, quantity, lowStockThreshold, shop |
| InventoryLog | product, actionType, quantity, previousStock, newStock, supplier, reason, performedBy, shop, date |
| Sale | invoiceNo, shop, customerName, customerPhone, items[], subtotal, discount, totalAmount, profit, paymentMethod, createdBy |
| Expense | shop, category, amount, expenseDate, description, createdBy |
| AuditLog | actionType, module, recordType, recordId, oldData, newData, performedBy, shopId |
| Notification | title, body, type, user, isRead, data |

---

## 11. Current Dashboard State (Post-Updates)

### Admin Dashboard
```
Header (muallimlogo + MUALLIM CARPETS brand + bell + avatar)
  ↓
Revenue Overview (glass card, gold border, animated number, growth badge, sparkline)
  ↓
4 Stat Tiles (Revenue / Profit / Sales / Expenses)
  ↓
Branch Overview (Branch 1, Branch 2, Warehouse — Revenue/Profit/Sales + Open Branch)
  ↓
Manager Logs (recent activity timeline + View All → AuditLogsScreen)
```
*Quick Actions: removed for admin*
*Analytics: removed for admin*
*Top Products: removed for admin*
*Background: admin_dashboard.jfif (16% opacity) + 70% dark overlay + showroom visible*

### Manager Dashboard
```
Header
  ↓
Revenue Overview
  ↓
4 Stat Tiles
  ↓
Your Branch (single branch card)
  ↓
Quick Actions (Add Product / New Sale / Stock Transfer / Expense Entry)
  ↓
Analytics (Weekly Sales bar chart / Monthly Profit line chart / Top Products)
```
*No Manager Logs for manager*

---

## 12. New Requirements Tracking

> Add new requirements below this line as they come in.

| # | Requirement | Status | Files Affected | Notes |
|---|---|---|---|---|
| | | | | |
