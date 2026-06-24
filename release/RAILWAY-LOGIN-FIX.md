# إصلاح تسجيل الدخول على Railway

التطبيق يتصل بـ: `https://chick-production.up.railway.app/api`

إذا ظهر **Invalid email or password** فالسبب غالباً أن Railway مربوط بقاعدة بيانات **غير** قاعدة Atlas في `server/.env`.

## الحل (5 دقائق)

### 1) افتح Railway → مشروع chick → **Variables**

### 2) انسخ من ملف `server/.env` السطر كاملاً:

```
MONGODB_URI=...
```

والصقه في Railway (نفس الاسم `MONGODB_URI`).

### 3) أضف أو عدّل:

```
INITIAL_ADMIN_EMAIL=admin@chick.com
INITIAL_ADMIN_PASSWORD=admin123
```

### 4) **Deploy** أو انتظر إعادة النشر التلقائية.

### 5) سجّل الدخول:

| | |
|---|---|
| Email | `admin@chick.com` |
| Password | `admin123` |

---

## إذا استمر الخطأ — مسح قاعدة Railway الحالية

بعد نشر آخر إصدار من GitHub:

1. على Railway أضف **مؤقتاً**:
   ```
   ALLOW_OPEN_BOOTSTRAP=true
   INITIAL_ADMIN_EMAIL=admin@chick.com
   INITIAL_ADMIN_PASSWORD=admin123
   ```
2. انتظر انتهاء الـ deploy.
3. في PowerShell:

```powershell
Invoke-RestMethod -Uri "https://chick-production.up.railway.app/api/setup/reset" -Method POST
```

4. احذف `ALLOW_OPEN_BOOTSTRAP` من Railway.
5. جرّب الدخول مرة أخرى.

---

## ملاحظة

قاعدة `chicken_farm` على Atlas **نظيفة** والمدير `admin@chick.com` موجود عليها.  
يجب أن يستخدم Railway **نفس** `MONGODB_URI` حتى يعمل التطبيق.
