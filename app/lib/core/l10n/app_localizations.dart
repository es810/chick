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
  'invalidEmail': {'en': 'Enter valid email', 'ar': 'أدخل بريداً إلكترونياً صالحاً'},
  'minPassword': {'en': 'Min 6 characters', 'ar': '6 أحرف على الأقل'},
  'fieldRequired': {'en': 'Required', 'ar': 'مطلوب'},
  'loginFailed': {'en': 'Login failed', 'ar': 'فشل تسجيل الدخول'},
  'cannotReachServer': {
    'en': 'Cannot reach server. Is the API running?',
    'ar': 'تعذّر الاتصال بالخادم. هل الخادم يعمل؟',
  },

  'dashboard': {'en': 'Dashboard', 'ar': 'لوحة التحكم'},
  'home': {'en': 'Home', 'ar': 'الرئيسية'},
  'invoices': {'en': 'Invoices', 'ar': 'الفواتير'},
  'navDistribution': {'en': 'Distribution', 'ar': 'التوزيع'},
  'stock': {'en': 'Stock', 'ar': 'المخزون'},
  'clients': {'en': 'Clients', 'ar': 'العملاء'},
  'clientsRoleHint': {
    'en': 'Clients are the recipients of distribution.',
    'ar': 'العميل هو الذي يتم التوزيع له',
  },
  'suppliers': {'en': 'Suppliers', 'ar': 'الموردين'},
  'suppliersRoleHint': {
    'en': 'Suppliers are where we receive goods from. Received goods sync to distribution stock.',
    'ar': 'المورد هو من نأخذ منه البضاعة — تُضاف تلقائياً لمخزون التوزيع',
  },
  'settings': {'en': 'Settings', 'ar': 'الإعدادات'},
  'appVersion': {'en': 'App version', 'ar': 'إصدار التطبيق'},
  'reports': {'en': 'Reports', 'ar': 'التقارير'},
  'employees': {'en': 'Employees', 'ar': 'الموظفون'},

  'adminDashboard': {'en': 'Admin Dashboard', 'ar': 'لوحة تحكم المدير'},
  'treasury': {'en': 'Treasury', 'ar': 'الخزينة'},
  'mainTreasury': {'en': 'Main Treasury', 'ar': 'الخزينة الرئيسية'},
  'setTreasuryAmount': {'en': 'Set treasury amount', 'ar': 'تعيين مبلغ الخزينة'},
  'treasuryAmount': {'en': 'Treasury amount (EGP)', 'ar': 'مبلغ الخزينة (ج.م)'},
  'openingBalance': {'en': 'Opening Balance', 'ar': 'رصيد أول المدة'},
  'treasuryFormula': {
    'en': 'Total = opening + collection + external − loading − expenses − withdrawals',
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
  'employeeTreasuryBalance': {'en': 'On hand now', 'ar': 'معاه الآن'},
  'employeeTreasuryTransfer': {'en': 'Transfer between employees', 'ar': 'تحويل بين الموظفين'},
  'transferFromEmployee': {'en': 'From employee', 'ar': 'من موظف'},
  'transferToEmployee': {'en': 'To employee', 'ar': 'إلى موظف'},
  'transferAmount': {'en': 'Transfer amount', 'ar': 'مبلغ التحويل'},
  'transferRecorded': {'en': 'Transfer completed', 'ar': 'تم التحويل'},
  'insufficientEmployeeTreasury': {
    'en': 'Insufficient employee treasury balance',
    'ar': 'رصيد خزنة الموظف غير كافٍ',
  },
  'sameEmployeeTransfer': {
    'en': 'Cannot transfer to the same employee',
    'ar': 'لا يمكن التحويل لنفس الموظف',
  },
  'selectFromEmployee': {'en': 'Select source employee', 'ar': 'اختر الموظف المرسل'},
  'selectToEmployee': {'en': 'Select destination employee', 'ar': 'اختر الموظف المستلم'},
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
  'dailyProfit': {'en': 'Daily Profit', 'ar': 'أرباح يومية'},
  'dailyProfitHint': {
    'en': 'Sales − load cost − expenses − discounts (business day: noon→noon Cairo)',
    'ar': 'المبيعات − التحميل − المصروفات − الخصومات (اليوم التشغيلي: ١٢ ظهرًا → ١٢ ظهرًا)',
  },
  'profitLoadCost': {'en': 'Load cost', 'ar': 'تكلفة التحميل'},
  'supplierDebtHint': {
    'en': 'Old debt only — does not affect profit. Add goods from supplier stock for load cost.',
    'ar': 'دين قديم فقط — لا يدخل الأرباح. تكلفة التحميل تُحسب عند إضافة البضاعة من مخزون المورد',
  },
  'monthlyProfit': {'en': 'Monthly Profit', 'ar': 'أرباح شهرية'},
  'selectMonth': {'en': 'Select month', 'ar': 'اختيار الشهر'},
  'afterSalariesDeduction': {'en': 'After advances', 'ar': 'بعد خصم السلف'},
  'monthlyProfitFormula': {
    'en': 'Period profit − salary advances taken this month (salary field is definition only)',
    'ar': 'أرباح الفترة − سلف الموظفين في الشهر (الراتب للتعريف فقط)',
  },
  'salaryAdvance': {'en': 'Salary advance', 'ar': 'طلب سلفة'},
  'addSalaryAdvance': {'en': 'Add salary advance', 'ar': 'إضافة سلفة'},
  'salaryAdvanceHint': {
    'en': 'Paid from treasury; counts in monthly profit. Salary field is the monthly allowance cap only.',
    'ar': 'تُصرف من الخزينة وتُخصم من الأرباح الشهرية. الراتب = سقف التعريف فقط وليس خصم تلقائي',
  },
  'salaryAdvanceRecorded': {'en': 'Salary advance recorded', 'ar': 'تم تسجيل السلفة'},
  'employeeSalary': {'en': 'Monthly salary', 'ar': 'الراتب الشهري'},
  'remainingSalaryAdvance': {'en': 'Remaining advance allowance', 'ar': 'المتبقي من السلفة لهذا الشهر'},
  'advanceExceedsSalary': {
    'en': 'Advance exceeds remaining salary for this month',
    'ar': 'مبلغ السلفة يتجاوز المتبقي من الراتب لهذا الشهر',
  },
  'deductedFromSalary': {
    'en': 'Deducted from salary and paid from treasury',
    'ar': 'تُخصم من الراتب وتُصرف من الخزينة',
  },
  'totalDiscount': {'en': 'Total Discount', 'ar': 'إجمالي الخصم'},
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
  'searchClients': {'en': 'Search by client name...', 'ar': 'ابحث باسم العميل...'},
  'noClientsMatch': {'en': 'No matching clients', 'ar': 'لا يوجد عملاء مطابقون'},
  'paymentStatus': {'en': 'Payment Status', 'ar': 'حالة الدفع'},
  'addItem': {'en': 'Add Item', 'ar': 'إضافة عنصر'},
  'chickenType': {'en': 'Chicken Type', 'ar': 'نوع الدجاج'},
  'quantity': {'en': 'Quantity', 'ar': 'الكمية'},
  'available': {'en': 'avail.', 'ar': 'متاح'},
  'estWeight': {'en': 'Est. weight', 'ar': 'الوزن التقديري'},
  'selectClientRequired': {'en': 'Please select a client', 'ar': 'يرجى اختيار عميل'},
  'selectChickenType': {'en': 'Please select chicken type for all items', 'ar': 'يرجى اختيار نوع الدجاج لجميع العناصر'},
  'insufficientStock': {'en': 'Insufficient stock for', 'ar': 'مخزون غير كافٍ لـ'},
  'availableInStock': {'en': 'Available in stock', 'ar': 'المتاح في المخزون'},
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
  'grossWeight': {'en': 'Gross Weight (kg)', 'ar': 'الوزن القايم (كجم)'},
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
  'damagedStock': {'en': 'Damaged Stock', 'ar': 'المخزون الهالك'},
  'damagedStockTreasuryNote': {
    'en': 'Not linked to main treasury',
    'ar': 'لا يؤثر على الخزينة الأساسية',
  },
  'distributionWeightSurplus': {
    'en': 'Distribution surplus (count/weight)',
    'ar': 'زيادة التوزيع (عدد/وزن)',
  },
  'distributionWeightRemainder': {
    'en': 'Leftover weight after distribution',
    'ar': 'متبقي وزن التوزيع',
  },
  'pendingSurplusOpen': {
    'en': 'Oversell pending — sold more than book stock; confirm write-off',
    'ar': 'زيادة توزيع معلّقة — وزّعت أكثر من وزن المخزون المسجّل؛ أكّد الهلاك',
  },
  'remainderOpenHint': {
    'en': 'Leftover weight after selling all birds under book kg — confirm write-off',
    'ar': 'متبقي وزن بعد بيع كل العدد بأقل من وزن المخزون — أكّد الهلاك',
  },
  'confirmWriteOffSurplus': {
    'en': 'Confirm write-off',
    'ar': 'تأكيد الهلاك',
  },
  'onHandWeightLabel': {
    'en': 'On-hand weight',
    'ar': 'الوزن عندي',
  },
  'writeOffSurplusDone': {
    'en': 'Surplus written off — on-hand restored',
    'ar': 'تم تأكيد الهلاك — لن يخصم من المخزون الجديد',
  },
  'surplusAlreadyWrittenOff': {
    'en': 'Written off',
    'ar': 'تم الهلاك',
  },
  'onHandStock': {
    'en': 'On-hand stock',
    'ar': 'عندي مخزون',
  },
  'pendingSurplusLabel': {
    'en': 'Pending surplus',
    'ar': 'زيادة معلّقة',
  },
  'bookStockLabel': {
    'en': 'Book stock',
    'ar': 'رصيد الدفتر',
  },
  'recordDamagedStock': {'en': 'Record damaged stock', 'ar': 'تسجيل مخزون هالك'},
  'writeOffStockTitle': {'en': 'Write off stock', 'ar': 'تسجيل هالك'},
  'writeOffStockAction': {'en': 'Write off', 'ar': 'هلك'},
  'remainingStockLabel': {'en': 'Remaining on hand', 'ar': 'المتبقي عندك'},
  'maxLabel': {'en': 'Max', 'ar': 'الحد الأقصى'},
  'confirmWriteOff': {'en': 'Confirm write-off', 'ar': 'تأكيد الهلاك'},
  'noStockLeftToWriteOff': {
    'en': 'No remaining stock to write off',
    'ar': 'لا يوجد مخزون متبقي للهلاك',
  },
  'weightExceedsStock': {
    'en': 'Weight exceeds remaining stock',
    'ar': 'الوزن أكبر من المتبقي في المخزون',
  },
  'damagedStockReason': {'en': 'Reason (optional)', 'ar': 'السبب (اختياري)'},
  'noDamagedStock': {'en': 'No damaged stock recorded', 'ar': 'لا يوجد مخزون هالك مسجّل'},
  'damagedStockRecorded': {'en': 'Damaged stock recorded', 'ar': 'تم تسجيل المخزون الهالك'},
  'damagedWeightKg': {'en': 'Weight (kg)', 'ar': 'الوزن (كجم)'},
  'selectStockType': {'en': 'Please select stock type', 'ar': 'يرجى اختيار نوع المخزون'},
  'noStockAddFirst': {'en': 'No stock items. Admin must add stock first.', 'ar': 'لا يوجد مخزون. يجب على المدير إضافة مخزون أولاً.'},

  'stockManagement': {'en': 'Stock Management', 'ar': 'إدارة المخزون'},
  'noStockItems': {'en': 'No stock items', 'ar': 'لا توجد عناصر مخزون'},
  'addStock': {'en': 'Add Stock', 'ar': 'إضافة مخزون'},
  'addStockMovement': {'en': 'Add Stock (IN Movement)', 'ar': 'إضافة مخزون (حركة دخول)'},
  'stockLocation': {'en': 'Location', 'ar': 'المكان'},
  'stockTypeLabel': {'en': 'Type', 'ar': 'النوع'},
  'stockPrice': {'en': 'Price', 'ar': 'السعر'},
  'stockTotal': {'en': 'Total', 'ar': 'إجمالي'},
  'stockTotalFormulaHint': {
    'en': 'Total = price/kg × net weight',
    'ar': 'الإجمالي = السعر/كغ × الوزن الصافي',
  },
  'netWeightFromGrossHint': {
    'en': 'Auto: gross − tare (you can still edit)',
    'ar': 'تلقائي: القايم − الفارغ (يمكن التعديل)',
  },
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
  'clientAdded': {'en': 'Client added', 'ar': 'تمت إضافة العميل'},
  'clientUpdated': {'en': 'Client updated', 'ar': 'تم تحديث العميل'},
  'clientDeleted': {'en': 'Client deleted', 'ar': 'تم حذف العميل'},
  'confirmDeleteClient': {
    'en': 'Delete this client? Their login account will also be removed.',
    'ar': 'حذف هذا العميل؟ سيتم حذف حساب الدخول أيضاً.',
  },
  'noSuppliersYet': {'en': 'No suppliers yet', 'ar': 'لا يوجد موردين بعد'},
  'searchSuppliers': {'en': 'Search by supplier name...', 'ar': 'ابحث باسم المورد...'},
  'noSuppliersMatch': {'en': 'No matching suppliers', 'ar': 'لا يوجد موردين مطابقون'},
  'addSupplier': {'en': 'Add Supplier', 'ar': 'إضافة مورد'},
  'editSupplier': {'en': 'Edit Supplier', 'ar': 'تعديل المورد'},
  'supplierAdded': {'en': 'Supplier added', 'ar': 'تمت إضافة المورد'},
  'supplierUpdated': {'en': 'Supplier updated', 'ar': 'تم تحديث المورد'},
  'supplierDeleted': {'en': 'Supplier deleted', 'ar': 'تم حذف المورد'},
  'confirmDeleteSupplier': {
    'en': 'Delete this supplier?',
    'ar': 'حذف هذا المورد؟',
  },
  'supplierStock': {'en': 'Supplier Goods', 'ar': 'بضاعة المورد'},
  'addSupplierStock': {'en': 'Add Goods from Supplier', 'ar': 'إضافة بضاعة من المورد'},
  'noSupplierStockYet': {
    'en': 'No goods received from this supplier yet',
    'ar': 'لم تُستلم بضاعة من هذا المورد بعد',
  },
  'supplierStockSynced': {
    'en': 'Goods added to distribution stock automatically.',
    'ar': 'تمت إضافة البضاعة لمخزون التوزيع تلقائياً',
  },
  'name': {'en': 'Name', 'ar': 'الاسم'},
  'phone': {'en': 'Phone', 'ar': 'رقم الهاتف'},
  'address': {'en': 'Address', 'ar': 'العنوان'},
  'clientDebt': {'en': 'Debt (EGP)', 'ar': 'المديونية (ج.م)'},
  'supplierDebt': {'en': 'Supplier debt (EGP)', 'ar': 'مديونية المورد (ج.م)'},
  'accountStatement': {'en': 'Account statement', 'ar': 'كشف حساب'},
  'debit': {'en': 'Debit', 'ar': 'مدين'},
  'credit': {'en': 'Credit', 'ar': 'دائن'},
  'statementBalanceAfter': {'en': 'Balance after', 'ar': 'الرصيد بعد'},
  'noStatementEntries': {'en': 'No transactions yet', 'ar': 'لا توجد حركات بعد'},
  'paySupplierDebt': {'en': 'Pay debt', 'ar': 'دفع الدين'},
  'supplierPaymentRecorded': {'en': 'Supplier payment recorded', 'ar': 'تم تسجيل دفع الدين'},
  'paymentAmount': {'en': 'Payment amount', 'ar': 'مبلغ الدفع'},
  'paymentDate': {'en': 'Payment date', 'ar': 'تاريخ الدفع'},
  'paymentExceedsSupplierDebt': {
    'en': 'Payment cannot exceed supplier debt',
    'ar': 'المبلغ يتجاوز مديونية المورد',
  },
  'notesOptional': {'en': 'Notes (optional)', 'ar': 'ملاحظات (اختياري)'},
  'loginId': {'en': 'Login ID (email)', 'ar': 'معرّف الدخول (البريد)'},
  'sessionExpired': {
    'en': 'Session expired. Please login again.',
    'ar': 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.',
  },
  'serverError': {
    'en': 'Server error. Try again or contact support.',
    'ar': 'خطأ في الخادم. أعد المحاولة أو تواصل مع الدعم.',
  },

  'reportsAnalytics': {'en': 'Reports & Analytics', 'ar': 'التقارير والتحليلات'},
  'revenue': {'en': 'Revenue', 'ar': 'الإيرادات'},
  'sales': {'en': 'Sales', 'ar': 'المبيعات'},
  'auditLogs': {'en': 'Audit Logs', 'ar': 'سجل التدقيق'},
  'dailyRevenue': {'en': 'Daily Revenue', 'ar': 'إيرادات اليوم'},
  'monthlyRevenueLabel': {'en': 'Monthly Revenue', 'ar': 'إيرادات الشهر'},
  'stockValue': {'en': 'Stock', 'ar': 'المخزون'},
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
    'en': 'Paying a supplier through the employee — reduces supplier debt and main treasury (not profit)',
    'ar': 'دفع لمورد عن طريق الموظف — ينقص مديونية المورد والخزنة (ولا يخصم من الأرباح)',
  },
  'addExpense': {'en': 'Add Expense', 'ar': 'إضافة مصروف'},
  'addDebt': {'en': 'Pay supplier via employee', 'ar': 'دفع لمورد عن طريق الموظف'},
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
  'addCollection': {'en': 'Add collection', 'ar': 'إضافة تحصيل'},
  'collectionInvoice': {'en': 'Collection invoice', 'ar': 'فاتورة تحصيل'},
  'collectionInvoices': {'en': 'Collection invoices', 'ar': 'فواتير التحصيل'},
  'noCollectionInvoices': {'en': 'No collection invoices yet', 'ar': 'لا توجد فواتير تحصيل'},
  'manageCollectionInvoices': {'en': 'Add and view collection invoices', 'ar': 'إضافة وعرض فواتير التحصيل'},
  'distributionInvoices': {'en': 'Distribution invoices', 'ar': 'فواتير التوزيع'},
  'collectedAmount': {'en': 'Collected amount', 'ar': 'المبلغ المحصّل'},
  'amountPaid': {'en': 'Amount paid', 'ar': 'المبلغ الذي دفعه'},
  'amountDeducted': {'en': 'Discount amount (optional)', 'ar': 'مبلغ الخصم (اختياري)'},
  'discountOptionalHint': {
    'en': 'Extra discount only — not the payment amount',
    'ar': 'خصم إضافي فقط — ليس مبلغ الدفع',
  },
  'balanceBeforePayment': {'en': 'Total before payment', 'ar': 'الإجمالي قبل الدفع'},
  'balanceAfterPayment': {'en': 'Total after payment', 'ar': 'الإجمالي بعد الدفع'},
  'collectorEmployee': {'en': 'Collector employee', 'ar': 'الموظف الذي حصل'},
  'selectCollector': {'en': 'Select collector', 'ar': 'اختر المحصّل'},
  'deductExceedsBalance': {
    'en': 'Deducted amount cannot exceed balance before payment',
    'ar': 'المبلغ المخصوم لا يمكن أن يتجاوز الإجمالي قبل الدفع',
  },
  'paymentExceedsBalance': {
    'en': 'Payment and discount cannot exceed total before payment',
    'ar': 'المبلغ المدفوع والخصم لا يمكن أن يتجاوزا الإجمالي قبل الدفع',
  },
  'addEmployee': {'en': 'Add Employee', 'ar': 'إضافة موظف'},
  'salary': {'en': 'Salary (EGP)', 'ar': 'الراتب (ج.م)'},
  'mySalary': {'en': 'My Salary', 'ar': 'راتبي'},
  'employeeAdded': {'en': 'Employee added', 'ar': 'تمت إضافة الموظف'},
  'employeeAddFailed': {'en': 'Could not add employee', 'ar': 'تعذّر إضافة الموظف'},
  'editEmployee': {'en': 'Edit Employee', 'ar': 'تعديل الموظف'},
  'employeeUpdated': {'en': 'Employee updated', 'ar': 'تم تحديث الموظف'},
  'employeeUpdateFailed': {'en': 'Could not update employee', 'ar': 'تعذّر تحديث الموظف'},
  'employeeDeleted': {'en': 'Employee removed', 'ar': 'تم إلغاء تفعيل الموظف'},
  'employeeDeleteFailed': {'en': 'Could not remove employee', 'ar': 'تعذّر حذف الموظف'},
  'confirmDeleteEmployee': {
    'en': 'Deactivate this employee? They will not be able to sign in.',
    'ar': 'إلغاء تفعيل هذا الموظف؟ لن يتمكن من تسجيل الدخول.',
  },
  'newPasswordOptional': {
    'en': 'New password (optional)',
    'ar': 'كلمة مرور جديدة (اختياري)',
  },
  'employeeActive': {'en': 'Active', 'ar': 'نشط'},
  'viewLedger': {'en': 'View ledger', 'ar': 'عرض الخزنة'},
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
  'myEmployeeTreasury': {'en': 'My Treasury', 'ar': 'خزينة الموظف'},
  'myDebt': {'en': 'My Debt (Goods)', 'ar': 'مديونيتي (البضاعة)'},
  'employeeTreasuryFormula': {
    'en': 'Collection + incoming transfer − expenses − advances − debts − outgoing transfer',
    'ar': 'تحصيل + تحويل وارد − مصروفات − سلف − مديونيات − تحويل صادر',
  },
  'viewAccountStatement': {'en': 'View account statement', 'ar': 'عرض كشف الحساب'},
  'myExpenses': {'en': 'My Expenses', 'ar': 'مصروفاتي'},
  'recordExpense': {'en': 'Record Expense', 'ar': 'تسجيل مصروف'},
  'expenseRecorded': {'en': 'Expense recorded', 'ar': 'تم تسجيل المصروف'},
  'recentExpenses': {'en': 'Recent expenses', 'ar': 'آخر المصروفات'},
  'recordGoodsDebt': {'en': 'Record Goods Debt', 'ar': 'تسجيل مديونية بضاعة'},
  'goodsDebtRecorded': {'en': 'Goods debt recorded', 'ar': 'تم تسجيل مديونية البضاعة'},
  'selectSupplier': {'en': 'Select supplier', 'ar': 'اختر المورد'},
  'supplierRequired': {'en': 'Please select a supplier', 'ar': 'يرجى اختيار المورد'},
  'goodsFromSupplier': {'en': 'Goods taken from supplier', 'ar': 'البضاعة المسحوبة من المورد'},

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
  String get invalidEmail => _get('invalidEmail');
  String get minPassword => _get('minPassword');
  String get fieldRequired => _get('fieldRequired');
  String get loginFailed => _get('loginFailed');
  String get cannotReachServer => _get('cannotReachServer');

  String get dashboard => _get('dashboard');
  String get home => _get('home');
  String get invoices => _get('invoices');
  String get navDistribution => _get('navDistribution');
  String get stock => _get('stock');
  String get clients => _get('clients');
  String get clientsRoleHint => _get('clientsRoleHint');
  String get suppliers => _get('suppliers');
  String get suppliersRoleHint => _get('suppliersRoleHint');
  String get settings => _get('settings');
  String get appVersion => _get('appVersion');
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
  String get employeeTreasuryBalance => _get('employeeTreasuryBalance');
  String get employeeTreasuryTransfer => _get('employeeTreasuryTransfer');
  String get transferFromEmployee => _get('transferFromEmployee');
  String get transferToEmployee => _get('transferToEmployee');
  String get transferAmount => _get('transferAmount');
  String get transferRecorded => _get('transferRecorded');
  String get insufficientEmployeeTreasury => _get('insufficientEmployeeTreasury');
  String get sameEmployeeTransfer => _get('sameEmployeeTransfer');
  String get selectFromEmployee => _get('selectFromEmployee');
  String get selectToEmployee => _get('selectToEmployee');
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
  String get dailyProfit => _get('dailyProfit');
  String get dailyProfitHint => _get('dailyProfitHint');
  String get profitLoadCost => _get('profitLoadCost');
  String get monthlyProfit => _get('monthlyProfit');
  String get selectMonth => _get('selectMonth');
  String get afterSalariesDeduction => _get('afterSalariesDeduction');
  String get monthlyProfitFormula => _get('monthlyProfitFormula');
  String get salaryAdvance => _get('salaryAdvance');
  String get addSalaryAdvance => _get('addSalaryAdvance');
  String get salaryAdvanceHint => _get('salaryAdvanceHint');
  String get salaryAdvanceRecorded => _get('salaryAdvanceRecorded');
  String get employeeSalary => _get('employeeSalary');
  String get remainingSalaryAdvance => _get('remainingSalaryAdvance');
  String get advanceExceedsSalary => _get('advanceExceedsSalary');
  String get deductedFromSalary => _get('deductedFromSalary');
  String get totalDiscount => _get('totalDiscount');
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
  String get searchClients => _get('searchClients');
  String get noClientsMatch => _get('noClientsMatch');
  String get paymentStatus => _get('paymentStatus');
  String get addItem => _get('addItem');
  String get chickenType => _get('chickenType');
  String get quantity => _get('quantity');
  String get available => _get('available');
  String get availableInStock => _get('availableInStock');
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
  String get damagedStock => _get('damagedStock');
  String get damagedStockTreasuryNote => _get('damagedStockTreasuryNote');
  String get distributionWeightSurplus => _get('distributionWeightSurplus');
  String get distributionWeightRemainder => _get('distributionWeightRemainder');
  String get pendingSurplusOpen => _get('pendingSurplusOpen');
  String get remainderOpenHint => _get('remainderOpenHint');
  String get confirmWriteOffSurplus => _get('confirmWriteOffSurplus');
  String get onHandWeightLabel => _get('onHandWeightLabel');
  String get writeOffSurplusDone => _get('writeOffSurplusDone');
  String get surplusAlreadyWrittenOff => _get('surplusAlreadyWrittenOff');
  String get onHandStock => _get('onHandStock');
  String get pendingSurplusLabel => _get('pendingSurplusLabel');
  String get bookStockLabel => _get('bookStockLabel');
  String get recordDamagedStock => _get('recordDamagedStock');
  String get writeOffStockTitle => _get('writeOffStockTitle');
  String get writeOffStockAction => _get('writeOffStockAction');
  String get remainingStockLabel => _get('remainingStockLabel');
  String get maxLabel => _get('maxLabel');
  String get confirmWriteOff => _get('confirmWriteOff');
  String get noStockLeftToWriteOff => _get('noStockLeftToWriteOff');
  String get weightExceedsStock => _get('weightExceedsStock');
  String get damagedStockReason => _get('damagedStockReason');
  String get noDamagedStock => _get('noDamagedStock');
  String get damagedStockRecorded => _get('damagedStockRecorded');
  String get damagedWeightKg => _get('damagedWeightKg');
  String get noStockAddFirst => _get('noStockAddFirst');

  String get stockManagement => _get('stockManagement');
  String get noStockItems => _get('noStockItems');
  String get addStock => _get('addStock');
  String get addStockMovement => _get('addStockMovement');
  String get stockLocation => _get('stockLocation');
  String get stockTypeLabel => _get('stockTypeLabel');
  String get stockPrice => _get('stockPrice');
  String get stockTotal => _get('stockTotal');
  String get stockTotalFormulaHint => _get('stockTotalFormulaHint');
  String get netWeightFromGrossHint => _get('netWeightFromGrossHint');
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
  String get clientAdded => _get('clientAdded');
  String get clientUpdated => _get('clientUpdated');
  String get clientDeleted => _get('clientDeleted');
  String get confirmDeleteClient => _get('confirmDeleteClient');
  String get noSuppliersYet => _get('noSuppliersYet');
  String get searchSuppliers => _get('searchSuppliers');
  String get noSuppliersMatch => _get('noSuppliersMatch');
  String get addSupplier => _get('addSupplier');
  String get editSupplier => _get('editSupplier');
  String get supplierAdded => _get('supplierAdded');
  String get supplierUpdated => _get('supplierUpdated');
  String get supplierDeleted => _get('supplierDeleted');
  String get confirmDeleteSupplier => _get('confirmDeleteSupplier');
  String get supplierStock => _get('supplierStock');
  String get addSupplierStock => _get('addSupplierStock');
  String get noSupplierStockYet => _get('noSupplierStockYet');
  String get supplierStockSynced => _get('supplierStockSynced');
  String get name => _get('name');
  String get phone => _get('phone');
  String get address => _get('address');
  String get clientDebt => _get('clientDebt');
  String get supplierDebt => _get('supplierDebt');
  String get supplierDebtHint => _get('supplierDebtHint');
  String get accountStatement => _get('accountStatement');
  String get debit => _get('debit');
  String get credit => _get('credit');
  String get statementBalanceAfter => _get('statementBalanceAfter');
  String get noStatementEntries => _get('noStatementEntries');
  String get paySupplierDebt => _get('paySupplierDebt');
  String get supplierPaymentRecorded => _get('supplierPaymentRecorded');
  String get paymentAmount => _get('paymentAmount');
  String get paymentDate => _get('paymentDate');
  String get paymentExceedsSupplierDebt => _get('paymentExceedsSupplierDebt');
  String get notesOptional => _get('notesOptional');
  String get loginId => _get('loginId');
  String get sessionExpired => _get('sessionExpired');
  String get serverError => _get('serverError');

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
  String get salary => _get('salary');
  String get mySalary => _get('mySalary');
  String get addCollection => _get('addCollection');
  String get collectionInvoice => _get('collectionInvoice');
  String get collectionInvoices => _get('collectionInvoices');
  String get noCollectionInvoices => _get('noCollectionInvoices');
  String get manageCollectionInvoices => _get('manageCollectionInvoices');
  String get distributionInvoices => _get('distributionInvoices');
  String get collectedAmount => _get('collectedAmount');
  String get amountPaid => _get('amountPaid');
  String get amountDeducted => _get('amountDeducted');
  String get discountOptionalHint => _get('discountOptionalHint');
  String get balanceBeforePayment => _get('balanceBeforePayment');
  String get balanceAfterPayment => _get('balanceAfterPayment');
  String get collectorEmployee => _get('collectorEmployee');
  String get selectCollector => _get('selectCollector');
  String get deductExceedsBalance => _get('deductExceedsBalance');
  String get paymentExceedsBalance => _get('paymentExceedsBalance');
  String get employeeAdded => _get('employeeAdded');
  String get employeeAddFailed => _get('employeeAddFailed');
  String get editEmployee => _get('editEmployee');
  String get employeeUpdated => _get('employeeUpdated');
  String get employeeUpdateFailed => _get('employeeUpdateFailed');
  String get employeeDeleted => _get('employeeDeleted');
  String get employeeDeleteFailed => _get('employeeDeleteFailed');
  String get confirmDeleteEmployee => _get('confirmDeleteEmployee');
  String get newPasswordOptional => _get('newPasswordOptional');
  String get employeeActive => _get('employeeActive');
  String get viewLedger => _get('viewLedger');
  String get editStock => _get('editStock');
  String get stockUpdated => _get('stockUpdated');
  String get stockDeleted => _get('stockDeleted');
  String get confirmDeleteStock => _get('confirmDeleteStock');
  String get confirmDeleteStockWithQty => _get('confirmDeleteStockWithQty');
  String get viewOnlyStock => _get('viewOnlyStock');
  String get myEmployeeTreasury => _get('myEmployeeTreasury');
  String get employeeTreasuryFormula => _get('employeeTreasuryFormula');
  String get viewAccountStatement => _get('viewAccountStatement');
  String get myDebt => _get('myDebt');
  String get myExpenses => _get('myExpenses');
  String get recordExpense => _get('recordExpense');
  String get expenseRecorded => _get('expenseRecorded');
  String get recentExpenses => _get('recentExpenses');
  String get recordGoodsDebt => _get('recordGoodsDebt');
  String get goodsDebtRecorded => _get('goodsDebtRecorded');
  String get selectSupplier => _get('selectSupplier');
  String get supplierRequired => _get('supplierRequired');
  String get goodsFromSupplier => _get('goodsFromSupplier');

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
    if (path.contains('collection-invoices')) return collectionInvoices;
    if (path.contains('invoices')) return invoices;
    if (path.contains('treasury')) return treasury;
    if (path.contains('stock')) return stock;
    if (path.contains('clients')) return clients;
    if (path.contains('suppliers')) return suppliers;
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
