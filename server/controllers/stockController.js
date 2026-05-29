const Stock = require('../models/Stock');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { addStock, getLowStockAlerts, getMovements, deleteStockType } = require('../services/stockService');
const { logAction } = require('../services/auditService');

const getStock = asyncHandler(async (req, res) => {
  const stocks = await Stock.find().sort({ chickenType: 1 });
  const lowStock = stocks.filter((s) => s.quantity <= s.lowStockThreshold);
  res.json({ success: true, data: stocks, lowStockAlerts: lowStock });
});

const createStock = asyncHandler(async (req, res) => {
  const stock = await addStock(req.body, req.user);
  res.status(201).json({ success: true, data: stock });
});

const updateStock = asyncHandler(async (req, res) => {
  const {
    location,
    chickenType,
    averageWeight,
    pricePerKg,
    lowStockThreshold,
    quantity,
    tareWeight,
    netWeight,
    totalAmount,
  } = req.body;
  const updates = {};
  if (location != null) updates.location = location;
  if (chickenType != null) updates.chickenType = chickenType;
  if (averageWeight != null) updates.averageWeight = averageWeight;
  if (pricePerKg != null) updates.pricePerKg = pricePerKg;
  if (lowStockThreshold != null) updates.lowStockThreshold = lowStockThreshold;
  if (quantity != null) updates.quantity = quantity;
  if (tareWeight != null) updates.tareWeight = tareWeight;
  if (netWeight != null) updates.netWeight = netWeight;
  if (totalAmount != null) {
    updates.totalAmount = totalAmount;
  } else if (pricePerKg != null && netWeight != null) {
    updates.totalAmount = pricePerKg * netWeight;
  }

  const stock = await Stock.findByIdAndUpdate(req.params.id, updates, {
    new: true,
    runValidators: true,
  });
  if (!stock) throw new ApiError(404, 'Stock not found');
  await logAction(req.user._id, req.user.name, 'UPDATE_STOCK', stock.chickenType);
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
