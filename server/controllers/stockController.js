const Stock = require('../models/Stock');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const {
  addStock,
  getLowStockAlerts,
  getMovements,
  deleteStockType,
  updateStockSnapshot,
} = require('../services/stockService');

const getStock = asyncHandler(async (req, res) => {
  const { syncPendingSurplusFromOpenEntries } = require('../services/damagedStockService');
  await syncPendingSurplusFromOpenEntries();
  const stocks = await Stock.find().sort({ chickenType: 1 });
  const lowStock = stocks.filter(
    (s) => (s.usableQuantity ?? s.quantity) <= s.lowStockThreshold
  );
  res.json({ success: true, data: stocks, lowStockAlerts: lowStock });
});

const createStock = asyncHandler(async (req, res) => {
  const stock = await addStock(req.body, req.user);
  res.status(201).json({ success: true, data: stock });
});

const updateStock = asyncHandler(async (req, res) => {
  const stock = await updateStockSnapshot(req.params.id, req.body, req.user);
  if (!stock) throw new ApiError(404, 'Stock not found');
  res.json({ success: true, data: stock });
});

const deleteStock = asyncHandler(async (req, res) => {
  await deleteStockType(req.params.id, req.user);
  res.json({ success: true, message: 'Stock deleted' });
});

const getStockMovements = asyncHandler(async (req, res) => {
  const result = await getMovements(req.query, req.query.page, req.query.limit);
  res.json({ success: true, ...result });
});

const getAlerts = asyncHandler(async (req, res) => {
  const alerts = await getLowStockAlerts();
  res.json({ success: true, data: alerts });
});

module.exports = { getStock, createStock, updateStock, deleteStock, getStockMovements, getAlerts };
