const asyncHandler = require('../utils/asyncHandler');
const {
  listStockLoads,
  finishStockLoad,
  getLoadStatement,
} = require('../services/stockLoadService');

const listHandler = asyncHandler(async (req, res) => {
  const loads = await listStockLoads({
    status: req.query.status,
    chickenType: req.query.chickenType,
    stockId: req.query.stockId,
  });
  res.json({ success: true, data: loads });
});

const finishHandler = asyncHandler(async (req, res) => {
  const load = await finishStockLoad(req.params.id, req.user);
  res.json({ success: true, data: load });
});

const statementHandler = asyncHandler(async (req, res) => {
  const data = await getLoadStatement(req.params.id);
  res.json({ success: true, data });
});

module.exports = { listHandler, finishHandler, statementHandler };
