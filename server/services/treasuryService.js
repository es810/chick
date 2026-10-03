const Treasury = require('../models/Treasury');
const TreasuryMovement = require('../models/TreasuryMovement');
const CollectionInvoice = require('../models/CollectionInvoice');
const EmployeeLedger = require('../models/EmployeeLedger');
const Invoice = require('../models/Invoice');
const Stock = require('../models/Stock');
const StockMovement = require('../models/StockMovement');
const SupplierStock = require('../models/SupplierStock');
const SalaryAdvance = require('../models/SalaryAdvance');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');
const { getCairoMonthRange, CAIRO_OFFSET_MS } = require('../utils/businessCalendar');

const MAIN_KEY = 'main';

/**
 * إجمالي الخزنة (نقدي) =
 * رصيد أول المدة + التحصيل + إيرادات خارجية
 * − التحميل − المصاريف − السحوبات
 * قيمة المخزون لا تدخل في رصيد الخزنة النقدية.
 */
const computeTreasuryBalance = ({
  openingBalance,
  totalCollection,
  externalRevenue,
  totalLoading,
  otherExpenses,
  withdrawals,
}) =>
  openingBalance +
  totalCollection +
  externalRevenue -
  totalLoading -
  otherExpenses -
  withdrawals;

/**
 * أرباح الفترة = المبيعات − تكلفة البضاعة عند التحميل − المصروفات − الخصومات
 *
 * التحميل = صافي تكلفة الشراء في الفترة:
 *   حركات دخول (IN) − تعديلات النقص (OUT بدون فاتورة توزيع، وغير الهالك)
 * تعديل المخزون بالزيادة/النقص يحرّك الربح فوراً. دفع المورد يخص الخزنة فقط.
 */
const movementAmountExpr = { $ifNull: ['$totalAmount', 0] };

const computeProfitForPeriod = async (startDate, endDate = null) => {
  const invoiceDateFilter = endDate
    ? { $gte: startDate, $lt: endDate }
    : { $gte: startDate };
  const createdAtFilter = endDate
    ? { $gte: startDate, $lt: endDate }
    : { $gte: startDate };
  const [salesAgg, loadingInAgg, loadingAdjOutAgg, expenseAgg, discountAgg] =
    await Promise.all([
      Invoice.aggregate([
        { $match: { createdAt: invoiceDateFilter } },
        { $group: { _id: null, total: { $sum: '$totalPrice' } } },
      ]),
      StockMovement.aggregate([
        {
          $match: {
            type: 'IN',
            createdAt: createdAtFilter,
            reason: { $not: /stock restored/i },
          },
        },
        { $group: { _id: null, total: { $sum: movementAmountExpr } } },
      ]),
      // Edits/removals that reduce purchase cost (not sales, not damaged write-off).
      StockMovement.aggregate([
        {
          $match: {
            type: 'OUT',
            createdAt: createdAtFilter,
            $and: [
              {
                $or: [{ invoiceId: null }, { invoiceId: { $exists: false } }],
              },
              { reason: { $not: /Damaged stock/i } },
            ],
          },
        },
        { $group: { _id: null, total: { $sum: movementAmountExpr } } },
      ]),
      EmployeeLedger.aggregate([
        { $match: { type: 'expense', createdAt: createdAtFilter } },
        { $group: { _id: null, total: { $sum: '$amount' } } },
      ]),
      CollectionInvoice.aggregate([
        {
          $match: {
            collectionDate: createdAtFilter,
            amountDeducted: { $gt: 0 },
          },
        },
        { $group: { _id: null, total: { $sum: '$amountDeducted' } } },
      ]),
    ]);

  const revenue = salesAgg[0]?.total || 0;
  const loading = Math.max(
    0,
    (loadingInAgg[0]?.total || 0) - (loadingAdjOutAgg[0]?.total || 0)
  );
  const expenses = expenseAgg[0]?.total || 0;
  const discount = discountAgg[0]?.total || 0;
  const profit = revenue - loading - expenses - discount;

  return { revenue, loading, expenses, discount, profit };
};

/**
 * أرباح اليوم = المبيعات − تكلفة التحميل − المصروفات − الخصومات
 * السحوبات ودفع المورد يخصّان الخزنة فقط وليسا جزءاً من معادلة الأرباح.
 */
const computeDailyProfit = async (startDate, endDate) =>
  computeProfitForPeriod(startDate, endDate);

/**
 * أرباح الشهر = أرباح الفترة − سلف الموظفين في الشهر
 * حقل الراتب على الموظف للتعريف/سقف السلفة فقط — لا يُخصم تلقائياً من الربح.
 */
const computeMonthlyProfit = async (year, month) => {
  const { start: startOfMonth, end: startOfNextMonth } = getCairoMonthRange(year, month);

  const [periodProfit, advanceAgg] = await Promise.all([
    computeProfitForPeriod(startOfMonth, startOfNextMonth),
    SalaryAdvance.aggregate([
      {
        $match: {
          advanceDate: { $gte: startOfMonth, $lt: startOfNextMonth },
        },
      },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]),
  ]);

  const dailyProfitsTotal = periodProfit.profit;
  const salaryAdvances = advanceAgg[0]?.total || 0;

  return {
    year,
    month,
    dailyProfitsTotal,
    /** @deprecated use salaryAdvances — kept for app compatibility */
    salaries: salaryAdvances,
    salaryAdvances,
    profit: dailyProfitsTotal - salaryAdvances,
    breakdown: periodProfit,
  };
};

/**
 * Day-by-day profit for a Cairo business month (noon → noon each day).
 * Loads month data once and buckets in memory (avoids ~150 aggregations).
 * Month net profit still subtracts salary advances once at the summary level.
 */
const computeDailyProfitsForMonth = async (year, month) => {
  const { start: startOfMonth, end: startOfNextMonth } = getCairoMonthRange(year, month);
  const monthly = await computeMonthlyProfit(year, month);

  const dayStarts = [];
  for (
    let t = startOfMonth.getTime();
    t < startOfNextMonth.getTime();
    t += 24 * 60 * 60 * 1000
  ) {
    dayStarts.push(new Date(t));
  }

  const dateFilter = { $gte: startOfMonth, $lt: startOfNextMonth };
  const [
    invoices,
    loadingIns,
    loadingAdjOuts,
    expenses,
    discounts,
  ] = await Promise.all([
    Invoice.find({ createdAt: dateFilter }).select('createdAt totalPrice').lean(),
    StockMovement.find({
      type: 'IN',
      createdAt: dateFilter,
      reason: { $not: /stock restored/i },
    })
      .select('createdAt totalAmount')
      .lean(),
    StockMovement.find({
      type: 'OUT',
      createdAt: dateFilter,
      $and: [
        { $or: [{ invoiceId: null }, { invoiceId: { $exists: false } }] },
        { reason: { $not: /Damaged stock/i } },
      ],
    })
      .select('createdAt totalAmount')
      .lean(),
    EmployeeLedger.find({ type: 'expense', createdAt: dateFilter })
      .select('createdAt amount')
      .lean(),
    CollectionInvoice.find({
      collectionDate: dateFilter,
      amountDeducted: { $gt: 0 },
    })
      .select('collectionDate amountDeducted')
      .lean(),
  ]);

  const dayKey = (date) => {
    const t = new Date(date).getTime();
    // Snap to Cairo business-day start (noon).
    const cairo = new Date(t + CAIRO_OFFSET_MS);
    const y = cairo.getUTCFullYear();
    const m = cairo.getUTCMonth();
    const d = cairo.getUTCDate();
    const hour = cairo.getUTCHours();
    const dayOffset = hour < 12 ? -1 : 0;
    const labelCairo = new Date(Date.UTC(y, m, d + dayOffset, 12, 0, 0, 0));
    const yy = labelCairo.getUTCFullYear();
    const mm = String(labelCairo.getUTCMonth() + 1).padStart(2, '0');
    const dd = String(labelCairo.getUTCDate()).padStart(2, '0');
    return `${yy}-${mm}-${dd}`;
  };

  const buckets = new Map();
  for (const dayStart of dayStarts) {
    const cairo = new Date(dayStart.getTime() + CAIRO_OFFSET_MS);
    const y = cairo.getUTCFullYear();
    const m = String(cairo.getUTCMonth() + 1).padStart(2, '0');
    const d = String(cairo.getUTCDate()).padStart(2, '0');
    buckets.set(`${y}-${m}-${d}`, {
      date: `${y}-${m}-${d}`,
      revenue: 0,
      loadingIn: 0,
      loadingOut: 0,
      expenses: 0,
      discount: 0,
    });
  }

  const bump = (key, field, amount) => {
    const row = buckets.get(key);
    if (!row) return;
    row[field] += amount;
  };

  for (const inv of invoices) {
    bump(dayKey(inv.createdAt), 'revenue', Number(inv.totalPrice) || 0);
  }
  for (const m of loadingIns) {
    bump(dayKey(m.createdAt), 'loadingIn', Number(m.totalAmount) || 0);
  }
  for (const m of loadingAdjOuts) {
    bump(dayKey(m.createdAt), 'loadingOut', Number(m.totalAmount) || 0);
  }
  for (const e of expenses) {
    bump(dayKey(e.createdAt), 'expenses', Number(e.amount) || 0);
  }
  for (const c of discounts) {
    bump(dayKey(c.collectionDate), 'discount', Number(c.amountDeducted) || 0);
  }

  const days = [...buckets.values()].map((row) => {
    const loading = Math.max(0, row.loadingIn - row.loadingOut);
    const profit = row.revenue - loading - row.expenses - row.discount;
    return {
      date: row.date,
      revenue: row.revenue,
      loading,
      expenses: row.expenses,
      discount: row.discount,
      profit,
    };
  });

  // Newest business day first (statement style).
  days.reverse();

  return {
    year,
    month,
    days,
    summary: {
      revenue: monthly.breakdown.revenue,
      loading: monthly.breakdown.loading,
      expenses: monthly.breakdown.expenses,
      discount: monthly.breakdown.discount,
      dailyProfitsTotal: monthly.dailyProfitsTotal,
      salaryAdvances: monthly.salaryAdvances,
      profit: monthly.profit,
    },
  };
};

const getOpeningBalance = (treasury) => treasury.openingBalance ?? treasury.balance ?? 0;

const getMainTreasury = async () => {
  let treasury = await Treasury.findOne({ key: MAIN_KEY }).populate('updatedBy', 'name');
  if (!treasury) {
    treasury = await Treasury.create({ key: MAIN_KEY, openingBalance: 0, balance: 0 });
    treasury = await Treasury.findById(treasury._id).populate('updatedBy', 'name');
  }
  return treasury;
};

const updateMainTreasury = async (openingBalance, user) => {
  const treasury = await getMainTreasury();
  const oldOpening = getOpeningBalance(treasury);
  treasury.openingBalance = openingBalance;
  treasury.balance = openingBalance;
  treasury.updatedBy = user._id;
  await treasury.save();

  await logAction(user._id, user.name, 'UPDATE_MAIN_TREASURY', MAIN_KEY, {
    from: oldOpening,
    to: openingBalance,
  });

  return Treasury.findById(treasury._id).populate('updatedBy', 'name');
};

const deductFromMainTreasury = async (amount, user, details = {}) => {
  const summary = await getTreasurySummary();
  if (summary.balance < amount) {
    throw new ApiError(400, 'Insufficient main treasury balance');
  }

  const movement = await TreasuryMovement.create({
    type: 'withdrawal',
    amount,
    description: details.reason || 'خصم من الخزينة',
    createdBy: user._id,
  });

  await logAction(user._id, user.name, 'DEDUCT_MAIN_TREASURY', MAIN_KEY, {
    amount,
    ...details,
  });

  return movement;
};

const ensureMainTreasuryInSession = async (session) => {
  let treasury = await Treasury.findOne({ key: MAIN_KEY }).session(session);
  if (!treasury) {
    [treasury] = await Treasury.create([{ key: MAIN_KEY, openingBalance: 0, balance: 0 }], { session });
  }
  return treasury;
};

/** @deprecated Balance is computed from ledger aggregates; kept for compatibility, no-op on balance field. */
const applyMainTreasuryDeltaInSession = async () => null;

const getTreasurySummary = async () => {
  const [treasury, ledgerRows, movementRows, supplierStockAgg, mainStockAgg] = await Promise.all([
    getMainTreasury(),
    EmployeeLedger.aggregate([{ $group: { _id: '$type', total: { $sum: '$amount' } } }]),
    TreasuryMovement.aggregate([{ $group: { _id: '$type', total: { $sum: '$amount' } } }]),
    SupplierStock.aggregate([
      {
        $group: {
          _id: null,
          total: {
            $sum: {
              $cond: [
                { $gt: ['$totalAmount', 0] },
                '$totalAmount',
                { $multiply: [{ $ifNull: ['$pricePerKg', 0] }, { $ifNull: ['$netWeight', 0] }] },
              ],
            },
          },
        },
      },
    ]),
    Stock.aggregate([
      {
        $group: {
          _id: null,
          total: {
            $sum: {
              $cond: [
                { $gt: ['$totalAmount', 0] },
                '$totalAmount',
                { $multiply: [{ $ifNull: ['$pricePerKg', 0] }, { $ifNull: ['$netWeight', 0] }] },
              ],
            },
          },
        },
      },
    ]),
  ]);

  let totalLoading = 0;
  let otherExpenses = 0;
  for (const row of ledgerRows) {
    if (row._id === 'debt') totalLoading = row.total;
    if (row._id === 'expense') otherExpenses = row.total;
  }

  let totalCollection = 0;
  let externalRevenue = 0;
  let withdrawals = 0;
  for (const row of movementRows) {
    if (row._id === 'collection') totalCollection = row.total;
    if (row._id === 'external_revenue') externalRevenue = row.total;
    if (row._id === 'withdrawal') withdrawals = row.total;
  }

  const openingBalance = getOpeningBalance(treasury);
  // Inventory value is tracked separately and does not inflate cash treasury.
  const mainStockValue = mainStockAgg[0]?.total || 0;
  const supplierStockValue = supplierStockAgg[0]?.total || 0;
  const stockValue = Math.max(mainStockValue, supplierStockValue);

  const balance = computeTreasuryBalance({
    openingBalance,
    totalCollection,
    externalRevenue,
    totalLoading,
    otherExpenses,
    withdrawals,
  });

  return {
    openingBalance,
    balance,
    totalCollection,
    externalRevenue,
    totalLoading,
    otherExpenses,
    withdrawals,
    stockValue,
    updatedAt: treasury.updatedAt,
    updatedByName: treasury.updatedBy?.name ?? null,
  };
};

const addExternalRevenue = async (amount, description, user) => {
  if (!amount || amount <= 0) throw new ApiError(400, 'Amount must be greater than zero');

  await TreasuryMovement.create({
    type: 'external_revenue',
    amount,
    description: description || 'إيراد خارجي',
    createdBy: user._id,
  });

  await logAction(user._id, user.name, 'TREASURY_EXTERNAL_REVENUE', MAIN_KEY, { amount, description });

  return getTreasurySummary();
};

const withdrawFromTreasury = async (amount, description, user) => {
  if (!amount || amount <= 0) throw new ApiError(400, 'Amount must be greater than zero');

  const summary = await getTreasurySummary();
  if (summary.balance < amount) {
    throw new ApiError(400, 'Insufficient main treasury balance');
  }

  await TreasuryMovement.create({
    type: 'withdrawal',
    amount,
    description: description || 'سحب من الخزنة',
    createdBy: user._id,
  });

  await logAction(user._id, user.name, 'TREASURY_WITHDRAWAL', MAIN_KEY, { amount, description });

  return getTreasurySummary();
};

const resetMainTreasury = async (user) => {
  const treasury = await getMainTreasury();
  const oldOpening = getOpeningBalance(treasury);

  treasury.openingBalance = 0;
  treasury.balance = 0;
  treasury.updatedBy = user._id;
  await treasury.save();

  await TreasuryMovement.deleteMany({});
  await CollectionInvoice.deleteMany({});

  await logAction(user._id, user.name, 'ZERO_MAIN_TREASURY', MAIN_KEY, {
    from: oldOpening,
    to: 0,
  });

  return getTreasurySummary();
};

module.exports = {
  getMainTreasury,
  getTreasurySummary,
  updateMainTreasury,
  deductFromMainTreasury,
  applyMainTreasuryDeltaInSession,
  addExternalRevenue,
  withdrawFromTreasury,
  resetMainTreasury,
  computeTreasuryBalance,
  computeProfitForPeriod,
  computeDailyProfit,
  computeMonthlyProfit,
  computeDailyProfitsForMonth,
};
