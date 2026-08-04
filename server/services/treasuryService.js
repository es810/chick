const Treasury = require('../models/Treasury');
const TreasuryMovement = require('../models/TreasuryMovement');
const CollectionInvoice = require('../models/CollectionInvoice');
const EmployeeLedger = require('../models/EmployeeLedger');
const Invoice = require('../models/Invoice');
const Stock = require('../models/Stock');
const SupplierStock = require('../models/SupplierStock');
const User = require('../models/User');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');
const { getCairoMonthRange } = require('../utils/businessCalendar');

const MAIN_KEY = 'main';

/**
 * إجمالي الخزنة =
 * رصيد أول المدة + التحصيل + إيرادات خارجية + قيمة المخزون
 * − التحميل − المصاريف − السحوبات
 */
const computeTreasuryBalance = ({
  openingBalance,
  totalCollection,
  externalRevenue,
  stockValue = 0,
  totalLoading,
  otherExpenses,
  withdrawals,
}) =>
  openingBalance +
  totalCollection +
  externalRevenue +
  stockValue -
  totalLoading -
  otherExpenses -
  withdrawals;

/**
 * أرباح الفترة = إجمالي التوزيعات − التحميل − المصروفات − الخصومات
 * الإيرادات = مجموع فواتير التوزيع (totalPrice) في الفترة
 */
const computeProfitForPeriod = async (startDate, endDate = null) => {
  const invoiceDateFilter = endDate
    ? { $gte: startDate, $lt: endDate }
    : { $gte: startDate };
  const createdAtFilter = endDate
    ? { $gte: startDate, $lt: endDate }
    : { $gte: startDate };
  const [salesAgg, loadingAgg, expenseAgg, discountAgg] = await Promise.all([
    Invoice.aggregate([
      { $match: { createdAt: invoiceDateFilter } },
      { $group: { _id: null, total: { $sum: '$totalPrice' } } },
    ]),
    EmployeeLedger.aggregate([
      { $match: { type: 'debt', createdAt: createdAtFilter } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]),
    EmployeeLedger.aggregate([
      { $match: { type: 'expense', createdAt: createdAtFilter } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]),
    CollectionInvoice.aggregate([
      {
        $match: {
          createdAt: createdAtFilter,
          amountDeducted: { $gt: 0 },
        },
      },
      { $group: { _id: null, total: { $sum: '$amountDeducted' } } },
    ]),
  ]);

  const revenue = salesAgg[0]?.total || 0;
  const loading = loadingAgg[0]?.total || 0;
  const expenses = expenseAgg[0]?.total || 0;
  const discount = discountAgg[0]?.total || 0;
  const profit = revenue - loading - expenses - discount;

  return { revenue, loading, expenses, discount, profit };
};

/**
 * أرباح اليوم = إجمالي المبيعات (التوزيع) − التحميل − المصروفات − الخصومات
 * السحوبات تخص الخزنة فقط وليست جزءاً من معادلة الأرباح.
 */
const computeDailyProfit = async (startDate, endDate) =>
  computeProfitForPeriod(startDate, endDate);

/**
 * أرباح الشهر = أرباح الفترة − إجمالي مرتبات الموظفين النشطين
 */
const computeMonthlyProfit = async (year, month) => {
  const { start: startOfMonth, end: startOfNextMonth } = getCairoMonthRange(year, month);

  const [periodProfit, salaryAgg] = await Promise.all([
    computeProfitForPeriod(startOfMonth, startOfNextMonth),
    User.aggregate([
      { $match: { role: 'employee', isActive: { $ne: false } } },
      { $group: { _id: null, total: { $sum: { $ifNull: ['$salary', 0] } } } },
    ]),
  ]);

  const dailyProfitsTotal = periodProfit.profit;
  const salaries = salaryAgg[0]?.total || 0;

  return {
    year,
    month,
    dailyProfitsTotal,
    salaries,
    salaryAdvances: salaries,
    profit: dailyProfitsTotal - salaries,
    breakdown: periodProfit,
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
  // Inventory in the main warehouse (for distribution & sales). Use the larger of
  // main stock vs supplier-stock records so older rows still show correctly.
  const mainStockValue = mainStockAgg[0]?.total || 0;
  const supplierStockValue = supplierStockAgg[0]?.total || 0;
  const stockValue = Math.max(mainStockValue, supplierStockValue);

  const balance = computeTreasuryBalance({
    openingBalance,
    totalCollection,
    externalRevenue,
    stockValue,
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
};
