import 'package:flutter/material.dart';
import '../utils/currency_formatter.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';

  static final Map<String, Map<String, String>> _strings = {
  'appName': {'en': 'Chicken Farm Management', 'ar': 'نظام إدارة مزرعة الدجاج'},
  'appNameShort': {'en': 'Chicken Farm', 'ar': 'مزرعة الدجاج'},
  'managementSystem': {'en': 'Management System', 'ar': 'نظام الإدارة'},
  'welcomeBack': {'en': 'Welcome Back', 'ar': 'مرحباً بعودتك'},
  'signInSubtitle': {'en': 'Sign in to Chicken Farm Management', 'ar': 'سجّل الدخول إلى نظام إدارة مزرعة الدجاج'},
  'email': {'en': 'Email', 'ar': 'البريد الإلكتروني'},
  'password': {'en': 'Password', 'ar': 'كلمة المرور'},
  'rememberSession': {'en': 'Remember session', 'ar': 'تذكر الجلسة'},
  'signIn': {'en': 'Sign In', 'ar': 'تسجيل الدخول'},
  'demoCredentials': {'en': 'Demo: admin@chickenfarm.com / admin123', 'ar': 'تجريبي: admin@chickenfarm.com / admin123'},
  'invalidEmail': {'en': 'Enter valid email', 'ar': 'أدخل بريداً إلكترونياً صالحاً'},
  'minPassword': {'en': 'Min 6 characters', 'ar': '6 أحرف على الأقل'},
  'loginFailed': {'en': 'Login failed', 'ar': 'فشل تسجيل الدخول'},
  'cannotReachServer': {
    'en': 'Cannot reach server. Is the API running?',
    'ar': 'تعذّر الاتصال بالخادم. هل الخادم يعمل؟',
  },

  'dashboard': {'en': 'Dashboard', 'ar': 'لوحة التحكم'},
  'home': {'en': 'Home', 'ar': 'الرئيسية'},
  'invoices': {'en': 'Invoices', 'ar': 'الفواتير'},
  'stock': {'en': 'Stock', 'ar': 'المخزون'},
  'clients': {'en': 'Clients', 'ar': 'العملاء'},
  'settings': {'en': 'Settings', 'ar': 'الإعدادات'},
  'reports': {'en': 'Reports', 'ar': 'التقارير'},
  'employees': {'en': 'Employees', 'ar': 'الموظفون'},

  'adminDashboard': {'en': 'Admin Dashboard', 'ar': 'لوحة تحكم المدير'},
  'treasury': {'en': 'Treasury', 'ar': 'الخزينة'},
  'mainTreasury': {'en': 'Main Treasury', 'ar': 'الخزينة الرئيسية'},
  'setTreasuryAmount': {'en': 'Set treasury amount', 'ar': 'تعيين مبلغ الخزينة'},
  'treasuryAmount': {'en': 'Treasury amount (EGP)', 'ar': 'مبلغ الخزينة (ج.م)'},
  'openingBalance': {'en': 'Opening Balance', 'ar': 'رصيد أول المدة'},
  'treasuryFormula': {
    'en': 'Total = opening + collection + external revenue − loading − expenses − withdrawals',
    'ar': 'الإجمالي = رصيد أول المدة + التحصيل + إيرادات خارجية − التحميل − المصاريف − السحوبات',
  },
  'treasuryUpdated': {'en': 'Main treasury updated', 'ar': 'تم تحديث الخزينة الرئيسية'},
  'editTreasury': {'en': 'Edit treasury', 'ar': 'تعديل الخزينة'},
  'zeroTreasury': {'en': 'Zero Treasury', 'ar': 'تصفير الخزنة'},
  'resetTreasury': {'en': 'Zero Treasury', 'ar': 'تصفير الخزنة'},
  'confirmZeroTreasury': {
    'en':
        'Set opening balance to zero and clear external revenue and withdrawal records? Invoice and employee records will still affect the calculated total.',
    'ar':
        'تصفير رصيد أول المدة ومسح الإيرادات الخارجية والسحوبات؟ الفواتير وسجل الموظفين تبقى محسوبة في الإجمالي حتى تحذفها.',
  },
  'confirmResetTreasury': {
    'en':
        'Set opening balance to zero and clear external revenue and withdrawal records? Invoice and employee records will still affect the calculated total.',
    'ar':
        'تصفير رصيد أول المدة ومسح الإيرادات الخارجية والسحوبات؟ الفواتير وسجل الموظفين تبقى محسوبة في الإجمالي حتى تحذفها.',
  },
  'treasuryZeroed': {'en': 'Treasury zeroed', 'ar': 'تم تصفير الخزنة'},
  'treasuryReset': {'en': 'Treasury zeroed', 'ar': 'تم تصفير الخزنة'},
  'financialTreasury': {'en': 'Financial Treasury', 'ar': 'الخزنة المالية'},
  'totalCollection': {'en': 'Total Collection', 'ar': 'إجمالي التحصيل'},
  'externalRevenue': {'en': 'External Revenue', 'ar': 'إيرادات خارجية'},
  'totalLoading': {'en': 'Total Loading', 'ar': 'إجمالي التحميل'},
  'otherExpenses': {'en': 'Other Expenses', 'ar': 'المصاريف الأخرى'},
  'withdrawals': {'en': 'Withdrawals', 'ar': 'سحوبات'},
  'totalTreasuryBalance': {'en': 'Total Treasury', 'ar': 'إجمالي الخزنة'},
  'withdrawFromTreasury': {'en': 'Withdraw from Treasury', 'ar': 'سحب من الخزنة'},
  'addExternalRevenue': {'en': 'Add External Revenue', 'ar': 'إضافة إيراد خارجي'},
  'employeesTreasury': {'en': 'Employees Treasury', 'ar': 'خزنة الموظفين'},
  'amountEgp': {'en': 'Amount (EGP)', 'ar': 'المبلغ (ج.م)'},
  'descriptionOptional': {'en': 'Description (optional)', 'ar': 'الوصف (اختياري)'},
  'revenueAdded': {'en': 'External revenue added', 'ar': 'تمت إضافة الإيراد الخارجي'},
  'withdrawalDone': {'en': 'Withdrawal completed', 'ar': 'تم السحب من الخزنة'},
  'invalidAmount': {'en': 'Enter a valid amount', 'ar': 'أدخل مبلغاً صحيحاً'},
  'manageEntries': {'en': 'Tap to manage entries', 'ar': 'اضغط لإدارة السجلات'},
  'addEntry': {'en': 'Add entry', 'ar': 'إضافة سجل'},
  'editEntry': {'en': 'Edit entry', 'ar': 'تعديل السجل'},
  'entryAdded': {'en': 'Entry added', 'ar': 'تمت الإضافة'},
  'entryUpdated': {'en': 'Entry updated', 'ar': 'تم التحديث'},
  'entryDeleted': {'en': 'Entry deleted', 'ar': 'تم الحذف'},
  'noTreasuryEntries': {'en': 'No entries yet', 'ar': 'لا توجد سجلات بعد'},
  'confirmDeleteTreasuryEntry': {
    'en': 'Delete this entry? Totals will be recalculated.',
    'ar': 'حذف هذا السجل؟ سيتم إعادة حساب الإجماليات.',
  },
  'selectEmployee': {'en': 'Select employee', 'ar': 'اختر الموظف'},
  'lastUpdated': {'en': 'Last updated', 'ar': 'آخر تحديث'},
  'receivables': {'en': 'Receivables', 'ar': 'المستحقات'},
  'employeeDashboard': {'en': 'Employee Dashboard', 'ar': 'لوحة تحكم الموظف'},
  'myAccount': {'en': 'My Account', 'ar': 'حسابي'},

  'monthlyRevenue': {'en': 'Monthly Revenue', 'ar': 'إيرادات الشهر'},
  'pendingPayments': {'en': 'Pending Payments', 'ar': 'مدفوعات معلّقة'},
  'lowStockAlerts': {'en': 'Low Stock Alerts', 'ar': 'تنبيهات نقص المخزون'},
  'salesTrend': {'en': 'Sales Trend', 'ar': 'اتجاه المبيعات'},
  'recentInvoices': {'en': 'Recent Invoices', 'ar': 'أحدث الفواتير'},
  'viewAll': {'en': 'View All', 'ar': 'عرض الكل'},
  'noSalesData': {'en': 'No sales data yet', 'ar': 'لا توجد بيانات مبيعات بعد'},
  'chartUnavailable': {'en': 'Chart unavailable', 'ar': 'الرسم البياني غير متاح'},

  'stockTypes': {'en': 'Stock Types', 'ar': 'أنواع المخزون'},
  'lowStock': {'en': 'Low Stock', 'ar': 'مخزون منخفض'},
  'myInvoices': {'en': 'My Invoices', 'ar': 'فواتيري'},
  'noInvoicesYet': {'en': 'No invoices yet', 'ar': 'لا توجد فواتير بعد'},
  'createFirstInvoice': {'en': 'Create your first invoice', 'ar': 'أنشئ أول فاتورة'},
  'newInvoice': {'en': 'New Invoice', 'ar': 'فاتورة جديدة'},

  'totalSpent': {'en': 'Total Spent', 'ar': 'إجمالي الإنفاق'},
  'pending': {'en': 'Pending', 'ar': 'معلّق'},
  'delivered': {'en': 'Delivered', 'ar': 'تم التسليم'},
  'paid': {'en': 'Paid', 'ar': 'مدفوع'},
  'partial': {'en': 'Partial', 'ar': 'جزئي'},

  'searchInvoices': {'en': 'Search invoices...', 'ar': 'بحث في الفواتير...'},
  'status': {'en': 'Status', 'ar': 'الحالة'},
  'all': {'en': 'All', 'ar': 'الكل'},
  'noInvoicesFound': {'en': 'No invoices found', 'ar': 'لم يتم العثور على فواتير'},
  'items': {'en': 'items', 'ar': 'عناصر'},

  'invoiceDetails': {'en': 'Invoice Details', 'ar': 'تفاصيل الفاتورة'},
  'downloadPdf': {'en': 'Download PDF', 'ar': 'تحميل PDF'},
  'shareWhatsApp': {'en': 'Share via WhatsApp', 'ar': 'مشاركة عبر واتساب'},
  'generatingPdf': {'en': 'Generating PDF...', 'ar': 'جاري إنشاء PDF...'},
  'pdfSaved': {'en': 'PDF saved successfully', 'ar': 'تم حفظ PDF بنجاح'},
  'pdfShared': {'en': 'Invoice shared', 'ar': 'تمت مشاركة الفاتورة'},
  'pdfError': {'en': 'Failed to generate PDF', 'ar': 'فشل إنشاء PDF'},
  'shareInvoice': {'en': 'Share Invoice', 'ar': 'مشاركة الفاتورة'},
  'client': {'en': 'Client', 'ar': 'العميل'},
  'employee': {'en': 'Employee', 'ar': 'الموظف'},
  'date': {'en': 'Date', 'ar': 'التاريخ'},
  'totalWeight': {'en': 'Total Weight', 'ar': 'الوزن الإجمالي'},
  'totalPrice': {'en': 'Total Price', 'ar': 'السعر الإجمالي'},
  'updateStatus': {'en': 'Update Status', 'ar': 'تحديث الحالة'},
  'paymentUpdated': {'en': 'Payment status updated', 'ar': 'تم تحديث حالة الدفع'},

  'createInvoice': {'en': 'Create Invoice', 'ar': 'إنشاء فاتورة'},
  'selectClient': {'en': 'Select Client', 'ar': 'اختر العميل'},
  'paymentStatus': {'en': 'Payment Status', 'ar': 'حالة الدفع'},
  'addItem': {'en': 'Add Item', 'ar': 'إضافة عنصر'},
  'chickenType': {'en': 'Chicken Type', 'ar': 'نوع الدجاج'},
  'quantity': {'en': 'Quantity', 'ar': 'الكمية'},
  'available': {'en': 'avail.', 'ar': 'متاح'},
  'estWeight': {'en': 'Est. weight', 'ar': 'الوزن التقديري'},
  'selectClientRequired': {'en': 'Please select a client', 'ar': 'يرجى اختيار عميل'},
  'selectChickenType': {'en': 'Please select chicken type for all items', 'ar': 'يرجى اختيار نوع الدجاج لجميع العناصر'},
  'insufficientStock': {'en': 'Insufficient stock for', 'ar': 'مخزون غير كافٍ لـ'},
  'invoiceCreated': {'en': 'Invoice created', 'ar': 'تم إنشاء الفاتورة'},
  'editInvoice': {'en': 'Edit Invoice', 'ar': 'تعديل الفاتورة'},
  'invoiceUpdated': {'en': 'Invoice updated', 'ar': 'تم تحديث الفاتورة'},
  'deleteInvoice': {'en': 'Delete Invoice', 'ar': 'حذف الفاتورة'},
  'confirmDeleteInvoice': {
    'en': 'Delete this invoice? Stock and balances will be reversed.',
    'ar': 'حذف هذه الفاتورة؟ سيتم استرجاع المخزون والأرصدة.',
  },
  'invoiceDeleted': {'en': 'Invoice deleted', 'ar': 'تم حذف الفاتورة'},
  'saveChanges': {'en': 'Save Changes', 'ar': 'حفظ التغييرات'},
  'notes': {'en': 'Notes', 'ar': 'ملاحظات'},
  'distributionReceipt': {'en': 'Distribution Receipt', 'ar': 'إيصال توزيع'},
  'itemCount': {'en': 'Count', 'ar': 'العدد'},
  'grossWeight': {'en': 'Gross Weight (kg)', 'ar': 'وزن القائم (كجم)'},
  'tareWeight': {'en': 'Tare Weight (kg)', 'ar': 'الوزن الفارغ (كجم)'},
  'tareWeightFormula': {
    'en': 'Tare weight = count × 8 kg',
    'ar': 'الوزن الفارغ = العدد × 8 كجم',
  },
  'netWeight': {'en': 'Net Weight (kg)', 'ar': 'الوزن الصافي (كجم)'},
  'mealTotal': {'en': 'Meal Total (EGP)', 'ar': 'حساب الوجبة (ج.م)'},
  'balanceBefore': {'en': 'Balance Before Invoice (EGP)', 'ar': 'المستحق القديم قبل الفاتورة (ج.م)'},
  'balanceAfter': {'en': 'Balance After Invoice (EGP)', 'ar': 'المستحق الجديد بعد الفاتورة (ج.م)'},
  'receiptPreview': {'en': 'Receipt Summary', 'ar': 'ملخص الإيصال'},
  'invalidWeights': {'en': 'Net weight must be greater than zero', 'ar': 'الوزن الصافي يجب أن يكون أكبر من صفر'},
  'selectStockType': {'en': 'Please select stock type', 'ar': 'يرجى اختيار نوع المخزون'},
  'noStockAddFirst': {'en': 'No stock items. Admin must add stock first.', 'ar': 'لا يوجد مخزون. يجب على المدير إضافة مخزون أولاً.'},

  'stockManagement': {'en': 'Stock Management', 'ar': 'إدارة المخزون'},
  'noStockItems': {'en': 'No stock items', 'ar': 'لا توجد عناصر مخزون'},
  'addStock': {'en': 'Add Stock', 'ar': 'إضافة مخزون'},
  'addStockMovement': {'en': 'Add Stock (IN Movement)', 'ar': 'إضافة مخزون (حركة دخول)'},
  'avgWeight': {'en': 'Avg Weight (kg)', 'ar': 'متوسط الوزن (كغ)'},
  'pricePerKg': {'en': 'Price/kg (EGP)', 'ar': 'السعر/كغ (ج.م)'},
  'add': {'en': 'Add', 'ar': 'إضافة'},
  'cancel': {'en': 'Cancel', 'ar': 'إلغاء'},
  'save': {'en': 'Save', 'ar': 'حفظ'},
  'delete': {'en': 'Delete', 'ar': 'حذف'},
  'lowStockBadge': {'en': 'LOW STOCK', 'ar': 'مخزون منخفض'},

  'noClientsYet': {'en': 'No clients yet', 'ar': 'لا يوجد عملاء بعد'},
  'addClient': {'en': 'Add Client', 'ar': 'إضافة عميل'},
  'editClient': {'en': 'Edit Client', 'ar': 'تعديل العميل'},
  'name': {'en': 'Name', 'ar': 'الاسم'},
  'phone': {'en': 'Phone', 'ar': 'الهاتف'},
  'address': {'en': 'Address', 'ar': 'العنوان'},

  'reportsAnalytics': {'en': 'Reports & Analytics', 'ar': 'التقارير والتحليلات'},
  'revenue': {'en': 'Revenue', 'ar': 'الإيرادات'},
  'sales': {'en': 'Sales', 'ar': 'المبيعات'},
  'auditLogs': {'en': 'Audit Logs', 'ar': 'سجل التدقيق'},
  'dailyRevenue': {'en': 'Daily Revenue', 'ar': 'إيرادات اليوم'},
  'monthlyRevenueLabel': {'en': 'Monthly Revenue', 'ar': 'إيرادات الشهر'},
  'stockValue': {'en': 'Stock Value', 'ar': 'قيمة المخزون'},
  'noSalesDataShort': {'en': 'No sales data', 'ar': 'لا توجد بيانات مبيعات'},

  'role': {'en': 'Role', 'ar': 'الدور'},
  'theme': {'en': 'Theme', 'ar': 'المظهر'},
  'system': {'en': 'System', 'ar': 'النظام'},
  'light': {'en': 'Light', 'ar': 'فاتح'},
  'dark': {'en': 'Dark', 'ar': 'داكن'},
  'language': {'en': 'Language', 'ar': 'اللغة'},
  'english': {'en': 'English', 'ar': 'English'},
  'arabic': {'en': 'العربية', 'ar': 'العربية'},
  'syncPending': {'en': 'Sync Pending Data', 'ar': 'مزامنة البيانات المعلّقة'},
  'syncSubtitle': {'en': 'Sync offline changes when online', 'ar': 'مزامنة التغييرات دون اتصال عند الاتصال'},
  'syncedItems': {'en': 'Synced {count} items', 'ar': 'تمت مزامنة {count} عناصر'},
  'nothingToSync': {'en': 'Nothing to sync', 'ar': 'لا يوجد ما يُزامَن'},
  'pushNotifications': {'en': 'Push Notifications', 'ar': 'إشعارات الدفع'},
  'lowStockAlertsEnabled': {'en': 'Low stock alerts enabled', 'ar': 'تنبيهات نقص المخزون مفعّلة'},
  'logout': {'en': 'Logout', 'ar': 'تسجيل الخروج'},

  'retry': {'en': 'Retry', 'ar': 'إعادة المحاولة'},
  'noEmployees': {'en': 'No employees', 'ar': 'لا يوجد موظفون'},
  'employeeDetails': {'en': 'Employee Details', 'ar': 'بيانات الموظف'},
  'expenses': {'en': 'Expenses', 'ar': 'المصروفات'},
  'employeeDebt': {'en': 'Goods Debt', 'ar': 'المديونية'},
  'employeeDebtHint': {
    'en': 'Goods carried by employee (deducted from main treasury)',
    'ar': 'البضاعة التي يحملها الموظف (تُخصم من الخزينة الرئيسية)',
  },
  'addExpense': {'en': 'Add Expense', 'ar': 'إضافة مصروف'},
  'addDebt': {'en': 'Add Goods Debt', 'ar': 'إضافة مديونية بضاعة'},
  'expenseDescriptionHint': {
    'en': 'e.g. Gasoline, maintenance...',
    'ar': 'مثل: بنزين، صيانة...',
  },
  'debtDescriptionHint': {
    'en': 'e.g. Chicken batch for delivery...',
    'ar': 'مثل: دفعة دجاج للتسليم...',
  },
  'deductedFromMainTreasury': {
    'en': 'Deducted from main treasury',
    'ar': 'تم الخصم من الخزينة الرئيسية',
  },
  'insufficientTreasury': {
    'en': 'Insufficient main treasury balance',
    'ar': 'رصيد الخزينة الرئيسية غير كافٍ',
  },
  'totalExpenses': {'en': 'Total Expenses', 'ar': 'إجمالي المصروفات'},
  'totalDebt': {'en': 'Total Debt', 'ar': 'إجمالي المديونية'},
  'noLedgerEntries': {'en': 'No entries yet', 'ar': 'لا توجد حركات بعد'},
  'amount': {'en': 'Amount (EGP)', 'ar': 'المبلغ (ج.م)'},
  'description': {'en': 'Description', 'ar': 'الوصف'},
  'addEmployee': {'en': 'Add Employee', 'ar': 'إضافة موظف'},
  'editStock': {'en': 'Edit Stock', 'ar': 'تعديل المخزون'},
  'stockUpdated': {'en': 'Stock updated', 'ar': 'تم تحديث المخزون'},
  'stockDeleted': {'en': 'Stock deleted', 'ar': 'تم حذف المخزون'},
  'confirmDeleteStockWithQty': {
    'en': 'Delete this stock type? Remaining quantity will be written off.',
    'ar': 'حذف نوع المخزون؟ سيتم شطب الكمية المتبقية.',
  },
  'confirmDeleteStock': {
    'en': 'Delete this stock type? Quantity must be zero.',
    'ar': 'حذف نوع المخزون؟ يجب أن تكون الكمية صفراً.',
  },
  'viewOnlyStock': {'en': 'View only — contact admin to modify stock', 'ar': 'عرض فقط — تواصل مع المدير لتعديل المخزون'},
  'myDebt': {'en': 'My Debt (Goods)', 'ar': 'مديونيتي (البضاعة)'},
  'myExpenses': {'en': 'My Expenses', 'ar': 'مصروفاتي'},
  'recordExpense': {'en': 'Record Expense', 'ar': 'تسجيل مصروف'},
  'expenseRecorded': {'en': 'Expense recorded', 'ar': 'تم تسجيل المصروف'},
  'recentExpenses': {'en': 'Recent expenses', 'ar': 'آخر المصروفات'},

  'roleAdmin': {'en': 'ADMIN', 'ar': 'مدير'},
  'roleEmployee': {'en': 'EMPLOYEE', 'ar': 'موظف'},
  'roleClient': {'en': 'CLIENT', 'ar': 'عميل'},
  };

  String _get(String key) {
    final map = _strings[key];
    if (map == null) return key;
    return map[locale.languageCode] ?? map['en'] ?? key;
  }

  String get appName => _get('appName');
  String get appNameShort => _get('appNameShort');
  String get managementSystem => _get('managementSystem');
  String get welcomeBack => _get('welcomeBack');
  String get signInSubtitle => _get('signInSubtitle');
  String get email => _get('email');
  String get password => _get('password');
  String get rememberSession => _get('rememberSession');
  String get signIn => _get('signIn');
  String get demoCredentials => _get('demoCredentials');
  String get invalidEmail => _get('invalidEmail');
  String get minPassword => _get('minPassword');
  String get loginFailed => _get('loginFailed');
  String get cannotReachServer => _get('cannotReachServer');

  String get dashboard => _get('dashboard');
  String get home => _get('home');
  String get invoices => _get('invoices');
  String get stock => _get('stock');
  String get clients => _get('clients');
  String get settings => _get('settings');
  String get reports => _get('reports');
  String get employees => _get('employees');

  String get adminDashboard => _get('adminDashboard');
  String get treasury => _get('treasury');
  String get mainTreasury => _get('mainTreasury');
  String get setTreasuryAmount => _get('setTreasuryAmount');
  String get treasuryAmount => _get('treasuryAmount');
  String get openingBalance => _get('openingBalance');
  String get treasuryFormula => _get('treasuryFormula');
  String get treasuryUpdated => _get('treasuryUpdated');
  String get editTreasury => _get('editTreasury');
  String get zeroTreasury => _get('zeroTreasury');
  String get resetTreasury => _get('resetTreasury');
  String get confirmZeroTreasury => _get('confirmZeroTreasury');
  String get confirmResetTreasury => _get('confirmResetTreasury');
  String get treasuryZeroed => _get('treasuryZeroed');
  String get treasuryReset => _get('treasuryReset');
  String get financialTreasury => _get('financialTreasury');
  String get totalCollection => _get('totalCollection');
  String get externalRevenue => _get('externalRevenue');
  String get totalLoading => _get('totalLoading');
  String get otherExpenses => _get('otherExpenses');
  String get withdrawals => _get('withdrawals');
  String get totalTreasuryBalance => _get('totalTreasuryBalance');
  String get withdrawFromTreasury => _get('withdrawFromTreasury');
  String get addExternalRevenue => _get('addExternalRevenue');
  String get employeesTreasury => _get('employeesTreasury');
  String get amountEgp => _get('amountEgp');
  String get descriptionOptional => _get('descriptionOptional');
  String get revenueAdded => _get('revenueAdded');
  String get withdrawalDone => _get('withdrawalDone');
  String get invalidAmount => _get('invalidAmount');
  String get manageEntries => _get('manageEntries');
  String get addEntry => _get('addEntry');
  String get editEntry => _get('editEntry');
  String get entryAdded => _get('entryAdded');
  String get entryUpdated => _get('entryUpdated');
  String get entryDeleted => _get('entryDeleted');
  String get noTreasuryEntries => _get('noTreasuryEntries');
  String get confirmDeleteTreasuryEntry => _get('confirmDeleteTreasuryEntry');
  String get selectEmployee => _get('selectEmployee');
  String get lastUpdated => _get('lastUpdated');
  String get receivables => _get('receivables');
  String get employeeDashboard => _get('employeeDashboard');
  String get myAccount => _get('myAccount');

  String get monthlyRevenue => _get('monthlyRevenue');
  String get pendingPayments => _get('pendingPayments');
  String get lowStockAlerts => _get('lowStockAlerts');
  String get salesTrend => _get('salesTrend');
  String get recentInvoices => _get('recentInvoices');
  String get viewAll => _get('viewAll');
  String get noSalesData => _get('noSalesData');
  String get chartUnavailable => _get('chartUnavailable');

  String get stockTypes => _get('stockTypes');
  String get lowStock => _get('lowStock');
  String get myInvoices => _get('myInvoices');
  String get noInvoicesYet => _get('noInvoicesYet');
  String get createFirstInvoice => _get('createFirstInvoice');
  String get newInvoice => _get('newInvoice');

  String get totalSpent => _get('totalSpent');
  String get pending => _get('pending');
  String get delivered => _get('delivered');
  String get paid => _get('paid');
  String get partial => _get('partial');

  String get searchInvoices => _get('searchInvoices');
  String get status => _get('status');
  String get all => _get('all');
  String get noInvoicesFound => _get('noInvoicesFound');
  String get items => _get('items');

  String get invoiceDetails => _get('invoiceDetails');
  String get downloadPdf => _get('downloadPdf');
  String get shareWhatsApp => _get('shareWhatsApp');
  String get generatingPdf => _get('generatingPdf');
  String get pdfSaved => _get('pdfSaved');
  String get pdfShared => _get('pdfShared');
  String get pdfError => _get('pdfError');
  String get shareInvoice => _get('shareInvoice');
  String get client => _get('client');
  String get employee => _get('employee');
  String get date => _get('date');
  String get totalWeight => _get('totalWeight');
  String get totalPrice => _get('totalPrice');
  String get updateStatus => _get('updateStatus');
  String get paymentUpdated => _get('paymentUpdated');

  String get createInvoice => _get('createInvoice');
  String get selectClient => _get('selectClient');
  String get paymentStatus => _get('paymentStatus');
  String get addItem => _get('addItem');
  String get chickenType => _get('chickenType');
  String get quantity => _get('quantity');
  String get available => _get('available');
  String estWeight(String kg) => '${_get('estWeight')}: $kg kg';
  String get selectClientRequired => _get('selectClientRequired');
  String get selectChickenType => _get('selectChickenType');
  String insufficientStock(String type) => '${_get('insufficientStock')} $type';
  String invoiceCreated(String number) => '${_get('invoiceCreated')}: $number';
  String get editInvoice => _get('editInvoice');
  String get invoiceUpdated => _get('invoiceUpdated');
  String get deleteInvoice => _get('deleteInvoice');
  String get confirmDeleteInvoice => _get('confirmDeleteInvoice');
  String get invoiceDeleted => _get('invoiceDeleted');
  String get saveChanges => _get('saveChanges');
  String get notes => _get('notes');
  String get distributionReceipt => _get('distributionReceipt');
  String get itemCount => _get('itemCount');
  String get grossWeight => _get('grossWeight');
  String get tareWeight => _get('tareWeight');
  String get tareWeightFormula => _get('tareWeightFormula');
  String get netWeight => _get('netWeight');
  String get mealTotal => _get('mealTotal');
  String get balanceBefore => _get('balanceBefore');
  String get balanceAfter => _get('balanceAfter');
  String get receiptPreview => _get('receiptPreview');
  String get invalidWeights => _get('invalidWeights');
  String get selectStockType => _get('selectStockType');
  String get noStockAddFirst => _get('noStockAddFirst');

  String get stockManagement => _get('stockManagement');
  String get noStockItems => _get('noStockItems');
  String get addStock => _get('addStock');
  String get addStockMovement => _get('addStockMovement');
  String get avgWeight => _get('avgWeight');
  String get pricePerKg => _get('pricePerKg');
  String get add => _get('add');
  String get cancel => _get('cancel');
  String get save => _get('save');
  String get delete => _get('delete');
  String get lowStockBadge => _get('lowStockBadge');

  String get noClientsYet => _get('noClientsYet');
  String get addClient => _get('addClient');
  String get editClient => _get('editClient');
  String get name => _get('name');
  String get phone => _get('phone');
  String get address => _get('address');

  String get reportsAnalytics => _get('reportsAnalytics');
  String get revenue => _get('revenue');
  String get sales => _get('sales');
  String get auditLogs => _get('auditLogs');
  String get dailyRevenue => _get('dailyRevenue');
  String get monthlyRevenueLabel => _get('monthlyRevenueLabel');
  String get stockValue => _get('stockValue');
  String get noSalesDataShort => _get('noSalesDataShort');

  String get role => _get('role');
  String get theme => _get('theme');
  String get system => _get('system');
  String get light => _get('light');
  String get dark => _get('dark');
  String get language => _get('language');
  String get english => _get('english');
  String get arabic => _get('arabic');
  String get syncPending => _get('syncPending');
  String get syncSubtitle => _get('syncSubtitle');
  String syncedItems(int count) => _get('syncedItems').replaceAll('{count}', '$count');
  String get nothingToSync => _get('nothingToSync');
  String get pushNotifications => _get('pushNotifications');
  String get lowStockAlertsEnabled => _get('lowStockAlertsEnabled');
  String get logout => _get('logout');

  String get retry => _get('retry');
  String get noEmployees => _get('noEmployees');
  String get employeeDetails => _get('employeeDetails');
  String get expenses => _get('expenses');
  String get employeeDebt => _get('employeeDebt');
  String get employeeDebtHint => _get('employeeDebtHint');
  String get addExpense => _get('addExpense');
  String get addDebt => _get('addDebt');
  String get expenseDescriptionHint => _get('expenseDescriptionHint');
  String get debtDescriptionHint => _get('debtDescriptionHint');
  String get deductedFromMainTreasury => _get('deductedFromMainTreasury');
  String get insufficientTreasury => _get('insufficientTreasury');
  String get totalExpenses => _get('totalExpenses');
  String get totalDebt => _get('totalDebt');
  String get noLedgerEntries => _get('noLedgerEntries');
  String get amount => _get('amount');
  String get description => _get('description');
  String get addEmployee => _get('addEmployee');
  String get editStock => _get('editStock');
  String get stockUpdated => _get('stockUpdated');
  String get stockDeleted => _get('stockDeleted');
  String get confirmDeleteStock => _get('confirmDeleteStock');
  String get confirmDeleteStockWithQty => _get('confirmDeleteStockWithQty');
  String get viewOnlyStock => _get('viewOnlyStock');
  String get myDebt => _get('myDebt');
  String get myExpenses => _get('myExpenses');
  String get recordExpense => _get('recordExpense');
  String get expenseRecorded => _get('expenseRecorded');
  String get recentExpenses => _get('recentExpenses');

  String roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return _get('roleAdmin');
      case 'employee':
        return _get('roleEmployee');
      case 'client':
        return _get('roleClient');
      default:
        return role.toUpperCase();
    }
  }

  String paymentStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return paid;
      case 'partial':
        return partial;
      case 'pending':
        return pending;
      default:
        return status;
    }
  }

  String navLabelForPath(String path) {
    if (path.contains('dashboard')) return path.contains('/client') ? home : dashboard;
    if (path.contains('invoices')) return invoices;
    if (path.contains('treasury')) return treasury;
    if (path.contains('stock')) return stock;
    if (path.contains('clients')) return clients;
    if (path.contains('settings')) return settings;
    return dashboard;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String formatCurrency(num amount, {int decimalDigits = 2}) {
    return CurrencyFormatter.format(
      amount,
      languageCode: Localizations.localeOf(this).languageCode,
      decimalDigits: decimalDigits,
    );
  }

  String formatCurrencyCompact(num amount) {
    return CurrencyFormatter.compact(
      amount,
      languageCode: Localizations.localeOf(this).languageCode,
    );
  }
}
