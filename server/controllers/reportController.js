const Invoice = require('../models/Invoice');
const Stock = require('../models/Stock');
const Client = require('../models/Client');
const AuditLog = require('../models/AuditLog');
const { getTreasurySummary, computeDailyProfit, computeMonthlyProfit } = require('../services/treasuryService');
const { getDamagedStockSummary } = require('../services/damagedStockService');
const { getCairoDayRange, getCairoMonthRange } = require('../utils/businessCalendar');
const asyncHandler = require('../utils/asyncHandler');

const getSalesReport = asyncHandler(async (req, res) => {
  const { startDate, endDate, groupBy = 'day' } = req.query;
  const match = { paymentStatus: { $in: ['paid', 'partial', 'pending'] } };

  if (startDate || endDate) {
    match.createdAt = {};
    if (startDate) match.createdAt.$gte = new Date(startDate);
    if (endDate) match.createdAt.$lte = new Date(endDate);
  }

  const dateFormat =
    groupBy === 'month' ? '%Y-%m' : groupBy === 'week' ? '%Y-W%V' : '%Y-%m-%d';

  const sales = await Invoice.aggregate([
    { $match: match },
    {
      $group: {
        _id: { $dateToString: { format: dateFormat, date: '$createdAt' } },
        totalSales: { $sum: '$totalPrice' },
        totalWeight: { $sum: '$totalWeight' },
        invoiceCount: { $sum: 1 },
        paidCount: {
          $sum: { $cond: [{ $eq: ['$paymentStatus', 'paid'] }, 1, 0] },
        },
      },
    },
    { $sort: { _id: 1 } },
  ]);

  const summary = await Invoice.aggregate([
    { $match: match },
    {
      $group: {
        _id: null,
        totalRevenue: { $sum: '$totalPrice' },
        totalInvoices: { $sum: 1 },
        avgOrderValue: { $avg: '$totalPrice' },
      },
    },
  ]);

  res.json({
    success: true,
    data: { sales, summary: summary[0] || {} },
  });
});

const getRevenueReport = asyncHandler(async (req, res) => {
  const now = new Date();
  const { start: startOfDay } = getCairoDayRange(now);
  const { start: startOfMonth } = getCairoMonthRange(now.getFullYear(), now.getMonth() + 1);

  const [daily, monthly, byStatus] = await Promise.all([
    Invoice.aggregate([
      { $match: { createdAt: { $gte: startOfDay } } },
      { $group: { _id: null, revenue: { $sum: '$totalPrice' }, count: { $sum: 1 } } },
    ]),
    Invoice.aggregate([
      { $match: { createdAt: { $gte: startOfMonth } } },
      { $group: { _id: null, revenue: { $sum: '$totalPrice' }, count: { $sum: 1 } } },
    ]),
    Invoice.aggregate([
      { $group: { _id: '$paymentStatus', total: { $sum: '$totalPrice' }, count: { $sum: 1 } } },
    ]),
  ]);

  const stockValue = await Stock.aggregate([
    {
      $project: {
        value: { $multiply: ['$quantity', '$pricePerKg', '$averageWeight'] },
      },
    },
    { $group: { _id: null, totalValue: { $sum: '$value' } } },
  ]);

  res.json({
    success: true,
    data: {
      daily: daily[0] || { revenue: 0, count: 0 },
      monthly: monthly[0] || { revenue: 0, count: 0 },
      byPaymentStatus: byStatus,
      stockValue: stockValue[0]?.totalValue || 0,
    },
  });
});

const getAuditLogs = asyncHandler(async (req, res) => {
  const { page = 1, limit = 50 } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  const [logs, total] = await Promise.all([
    AuditLog.find()
      .populate('userId', 'name role')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit)),
    AuditLog.countDocuments(),
  ]);

  res.json({
    success: true,
    data: logs,
    pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) },
  });
});

const getDashboard = asyncHandler(async (req, res) => {
  const now = new Date();
  const { start: startOfDay, end: endOfDay } = getCairoDayRange(now);
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

  const profitYear = parseInt(req.query.year, 10) || now.getFullYear();
  const profitMonth = parseInt(req.query.month, 10) || now.getMonth() + 1;
  if (profitMonth < 1 || profitMonth > 12) {
    return res.status(400).json({ success: false, message: 'Invalid month' });
  }

  const [
    invoiceStats,
    recentInvoices,
    treasurySummary,
    clientBalances,
    dailyProfit,
    monthlyProfit,
    damagedStockSummary,
  ] = await Promise.all([
    Invoice.aggregate([
      { $match: { createdAt: { $gte: startOfMonth } } },
      {
        $group: {
          _id: null,
          revenue: { $sum: '$totalPrice' },
          count: { $sum: 1 },
          pending: {
            $sum: { $cond: [{ $eq: ['$paymentStatus', 'pending'] }, 1, 0] },
          },
        },
      },
    ]),
    Invoice.find()
      .populate('clientId', 'name')
      .sort({ createdAt: -1 })
      .limit(5)
      .select('invoiceNumber totalPrice paymentStatus createdAt clientId'),
    getTreasurySummary(),
    Client.aggregate([{ $group: { _id: null, total: { $sum: '$balance' } } }]),
    computeDailyProfit(startOfDay, endOfDay),
    computeMonthlyProfit(profitYear, profitMonth),
    getDamagedStockSummary(),
  ]);

  res.json({
    success: true,
    data: {
      monthlyStats: invoiceStats[0] || { revenue: 0, count: 0, pending: 0 },
      dailyProfit,
      monthlyProfit,
      mainTreasury: {
        balance: treasurySummary.balance,
        openingBalance: treasurySummary.openingBalance,
        totalCollection: treasurySummary.totalCollection,
        externalRevenue: treasurySummary.externalRevenue,
        totalLoading: treasurySummary.totalLoading,
        otherExpenses: treasurySummary.otherExpenses,
        withdrawals: treasurySummary.withdrawals,
        updatedAt: treasurySummary.updatedAt,
        updatedByName: treasurySummary.updatedByName ?? null,
      },
      receivables: clientBalances[0]?.total || 0,
      damagedStock: damagedStockSummary,
      recentInvoices,
    },
  });
});

module.exports = { getSalesReport, getRevenueReport, getAuditLogs, getDashboard };
