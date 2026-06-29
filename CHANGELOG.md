# Changelog

## [1.6.0] — 2026-05-29

### Employee treasury
- **خزينة الموظف** on employee dashboard with full balance formula
- **كشف حساب** for employee treasury (collections, transfers, expenses, advances, debts)
- Admin **تحويل بين الموظفين** from Employees Treasury tab

### Suppliers (employee)
- **الموردين** tab for employees: view, add suppliers, add supplier stock
- Supplier selection when admin records employee goods debt

### Fixes & UI
- Collection nav label shows **فواتير التحصيل** (not التوزيع)
- Suppliers list trailing overflow fixed on employee screen
- Removed employee goods-debt entry form from dashboard (treasury card replaces it)
- Daily profit, supplier debt sync, invoices list refresh (from 1.5.x follow-ups)

## [1.5.0] — 2026-06-27

### Account statements
- **كشف حساب** for each client (distribution + collection invoices)
- **كشف حساب** for each supplier (goods + debt payments)
- Supplier **دفع الدين** from statement (treasury withdrawal)

### Employees
- **طلب سلفة** (salary advance) on employee detail — paid from treasury, deducted from salary allowance
- Monthly profit deducts **only salary advances taken** in the month (not full payroll)

### Fixes
- Collection invoice dialog: fix Riverpod `initState` crash
- `reset-db` clears salary advances and supplier payments
- Client collection balance uses live DB balance

## [1.4.0] — 2026-06-24

### Suppliers & clean production
- **Suppliers** (الموردين): add suppliers with name, location, phone
- **Supplier goods** sync automatically to distribution stock (الخزينة)
- Client vs supplier roles clarified in UI (client = distribution recipient, supplier = goods source)
- Nav label **التوزيع** for distribution invoices
- Clean release: no demo or test data; only initial admin via `INITIAL_ADMIN_EMAIL` / `INITIAL_ADMIN_PASSWORD`

## [1.3.0] — 2026-06-19

### Clean production release (no demo data)
- Removed auto-creation of demo users, clients, and test logins on server startup
- Removed demo credentials hint from the login screen
- Admin adds all data: stock, clients, employees, treasury via the app
- `npm run reset-db` wipes all collections for a fresh start
- First admin is created only when `INITIAL_ADMIN_EMAIL` and `INITIAL_ADMIN_PASSWORD` are set and the database has no users

### Profits & treasury
- Daily/monthly profit from distribution invoices; monthly profit with month picker minus salaries
- Collection invoice balance: paid amount + discount deducted correctly
- Damaged stock (separate from main treasury) with back navigation

### Distribution
- Invoices no longer blocked by stock cage count

## [1.2.0] — 2026-06-14

### Collection invoices
- Dedicated collection invoice model, API (`/api/collections`), and admin/employee screens
- Form: client, date, collector, amount paid/deducted, balance before/after
- Treasury integration via manual collection movements

### Clients (admin)
- Add/edit/delete clients with name, address, phone, debt, login email, and password
- Linked `User` account with `client` role for client app login

### Dashboard
- Split profits into **daily** (revenue − loading − expenses − discount) and **monthly** (invoice revenue)
- Main treasury card shows live balance

### Employees
- Salary field on create/edit; visible to employee on dashboard and settings
- Fix employee form `TextEditingController` dispose crash

### Auth & stability
- Expired JWT returns 401 instead of 500; auto logout without logout API loop
- Friendlier session-expired error messages (Arabic)

## [1.1.0] — 2026-05-29

### Employees
- Add employee with name, phone, email, and password (Arabic form)
- Edit employee: update details, optional new password, active/inactive toggle
- Deactivate employee from list menu (soft delete)
- Add button in Employees treasury tab when embedded in admin treasury

### Stock
- Gross weight (الوزن القايم) field on stock entry form
- Backend persistence for `grossWeight` on stock and movements

### Other
- Improved API error messages on employee screens
- Release APK built against Railway production API

## [1.0.1] — earlier

- Stock entry form: location, type, count, tare, net, price, auto total
- Treasury, invoices, Railway deploy, demo users bootstrap
