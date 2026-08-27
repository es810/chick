# Changelog

## [1.8.12] — 2026-08-27

### Distribution invoices
- Load all invoices (no longer capped at 20 so older ones stay visible)
- Group list by date with clear day separators (Today / Yesterday / full date)

## [1.8.11] — 2026-08-24

### Treasury, invoices & lists
- Optional supplier discount when paying via employee treasury (admin)
- Stop auto-filling distribution price from stock loading price
- Fix employee-to-employee treasury transfer save conflict
- Faster admin dashboard (skip heavy damaged-stock reconcile on load)

## [1.8.10] — 2026-08-21

### Clients & suppliers
- Fix list capped at 50: load all pages so older clients/suppliers stay visible after adding new ones

## [1.8.9] — 2026-08-20

### Invoices & stock
- Employee can edit/delete own distribution invoices; price editable on edit
- Chicken type on distribution receipt PDF and detail
- Clean number inputs (no trailing zeros or keyboard suggestions)
- Keep leftover kg when all cages distributed at lower weight (e.g. 500→450 kg)
- Stock write-off: تأكيد الهلاك button for pending loads; employees can confirm

## [1.8.8] — 2026-08-13

### Collection & suppliers
- Collection invoices open like distribution (detail, edit, delete, PDF)
- Fix collection edit balance restore (paid + discount)
- Optional **discount** when paying supplier debt (same idea as client collection)

## [1.8.3] — 2026-08-06

### Stock loading total
- Fix load cost doubling (50k → 100k): server always uses **price/kg × net**
- Net weight auto-fills from gross − tare; total formula shown on the form
- Prevent double-tap on Add/Save while the request is in flight

## [1.8.2] — 2026-08-06

### Profits & stock edits
- Profit follows stock load **edits** (increase/decrease), not only the first load
- Net goods cost = purchase IN − adjustment OUT (supplier/main stock corrections)
- Editing main stock now records movements so P&L stays in sync

## [1.8.1] — 2026-08-05

### Stock variance (عندي مخزون)
- Oversell count/weight becomes **pending surplus** until تأكيد الهلاك
- **عندي مخزون** = book stock − open surplus (new loads show correctly, e.g. 999 after +1 kg oversell)
- Confirming write-off clears pending without deducting stock again
- Manual هلك still removes leftover birds/weight from book stock

### Profits
- Daily/monthly profit deducts **goods cost at load time** (supplier stock IN), not when the supplier is paid
- Paying the supplier affects cash treasury only

### Distribution
- Allow distributing more birds than stock (count surplus), same as weight surplus

## [1.8.0] — 2026-08-04

### Search & distribution
- Search clients/suppliers by name in list screens
- Searchable client picker when creating/editing distribution and collection

### Profits & treasury
- Daily profit = sales − loading − expenses − discounts (**no withdrawals**)
- Main treasury is **cash only** (inventory value no longer inflates the total)
- Formula: opening + collection + external − loading − expenses − withdrawals

### Suppliers & employees
- Paying a supplier via employee updates **كشف حساب المورد** and reduces debt
- Those payments no longer reduce daily profit
- Employee detail shows **معاه الآن** (cash on hand) from treasury formula

### Damaged stock
- Distribution weight surplus (sold kg above book weight) appears under المخزون الهالك

## [1.7.0] — 2026-08-04

### Stock & invoices
- Distribution invoices **deduct stock** on create; restore on edit/delete
- Supplier stock **accumulates** debt/value when adding the same type again
- Main treasury balance includes **inventory value** (not supplier debt line)
- Removed separate «قيمة مخزون المورد» row from treasury UI

### Profits
- Daily profit includes collection **discounts** (`amountDeducted`)
- Monthly profit deducts **employee salaries** (active payroll)

### App & ops
- Bottom nav label **الفواتير** (not التوزيع)
- Mongo reconnect after disconnect; revenue report Stock import fix
- Debug auto-login only (not in release APK)
- Clean production DB: admin account only, no demo data

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
