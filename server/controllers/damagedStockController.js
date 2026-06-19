const asyncHandler = require('../utils/asyncHandler');
const {
  listDamagedStock,
  getDamagedStockSummary,
  recordDamagedStock,
} = require('../services/damagedStockService');

const listHandler = asyncHandler(async (req, res) => {
  const entries = await listDamagedStock();
  const summary = await getDamagedStockSummary();
  res.json({ success: true, data: entries, summary });
});

const createHandler = asyncHandler(async (req, res) => {
  const entry = await recordDamagedStock(req.body, req.user);
  res.status(201).json({ success: true, data: entry });
});

module.exports = { listHandler, createHandler };
