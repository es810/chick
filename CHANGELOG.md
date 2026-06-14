# Changelog

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
