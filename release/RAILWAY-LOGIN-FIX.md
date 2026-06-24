# إصلاح تسجيل الدخول على Railway

التطبيق يتصل بـ: `https://chick-production.up.railway.app/api`

## ضبط Railway (مهم)

في **Railway → Variables** أضف/عدّل:

```
MONGODB_URI=mongodb+srv://USER:PASSWORD@edu.yyiyscp.mongodb.net/chicken_farm?retryWrites=true&w=majority&appName=edu
INITIAL_ADMIN_EMAIL=admin@chick.com
INITIAL_ADMIN_PASSWORD=admin123
```

> **ملاحظة:** يجب وجود `/chicken_farm` في الرابط — لا تستخدم `...mongodb.net/?appName=...` بدون اسم قاعدة.

في **MongoDB Atlas → Network Access** أضف `0.0.0.0/0` حتى يصل Railway للقاعدة.

انتظر إعادة النشر ثم سجّل الدخول:

| Email | `admin@chick.com` |
| Password | `admin123` |

قاعدة `chicken_farm` على cluster **edu** مُفرَّغة والمدير جاهز.
