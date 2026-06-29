const Treasury = require('../models/Treasury');
const TreasuryMovement = require('../models/TreasuryMovement');
const CollectionInvoice = require('../models/CollectionInvoice');
const EmployeeLedger = require('../models/EmployeeLedger');
const SalaryAdvance = require('../models/SalaryAdvance');
const Invoice = require('../models/Invoice');
const User = require('../models/User');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');
const { getCairoMonthRange } = require('../utils/businessCalendar');

const MAIN_KEY = 'main';

/**
 * إجمالي الخزنة =
 * رصيد أول المدة + إجمالي التحصيل + الإيرادات الخارجية
 * − إجمالي التحميل − المصاريف الأخرى − السحوبات
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
  const collectionDateFilter = endDate
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
      { $match: { collectionDate: collectionDateFilter } },
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

const sumWithdrawalsForPeriod = async (startDate, endDate) => {
  const createdAtFilter = endDate
    ? { $gte: startDate, $lt: endDate }
    : { $gte: startDate };

  const rows = await TreasuryMovement.aggregate([
    { $match: { type: 'withdrawal', createdAt: createdAtFilter } },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);

  return rows[0]?.total || 0;
};

/** Daily profit includes same-day treasury withdrawals (supplier payments, advances, etc.). */
const computeDailyProfit = async (startDate, endDate) => {
  const base = await computeProfitForPeriod(startDate, endDate);
  const withdrawals = await sumWithdrawalsForPeriod(startDate, endDate);
  return {
    ...base,
    withdrawals,
    profit: base.profit - withdrawals,
  };
};

/**
 * أرباح الشهر = مجموع أرباح كل أيام الشهر − إجمالي السلف المأخوذة فقط
 */
const computeMonthlyProfit = async (year, month) => {
  const { start: startOfMonth, end: startOfNextMonth } = getCairoMonthRange(year, month);

  const [periodProfit, advancesAgg] = await Promise.all([
    computeProfitForPeriod(startOfMonth, startOfNextMonth),
    SalaryAdvance.aggregate([
      { $match: { advanceDate: { $gte: startOfMonth, $lt: startOfNextMonth } } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]),
  ]);

  const dailyProfitsTotal = periodProfit.profit;
  const salaryAdvances = advancesAgg[0]?.total || 0;

  return {
    year,
    month,
    dailyProfitsTotal,
    salaries: salaryAdvances,
    salaryAdvances,
    profit: dailyProfitsTotal - salaryAdvances,
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
  const [treasury, ledgerRows, movementRows] = await Promise.all([
    getMainTreasury(),
    EmployeeLedger.aggregate([{ $group: { _id: '$type', total: { $sum: '$amount' } } }]),
    TreasuryMovement.aggregate([{ $group: { _id: '$type', total: { $sum: '$amount' } } }]),
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
