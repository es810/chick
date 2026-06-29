const asyncHandler = require('../utils/asyncHandler');
const { getEmployeeLedger, addLedgerEntry } = require('../services/employeeLedgerService');
const {
  getEmployeeTreasurySummary,
  getEmployeeTreasuryStatement,
} = require('../services/employeeTreasuryService');

const getMyLedger = asyncHandler(async (req, res) => {
  const data = await getEmployeeLedger(req.user._id);
  res.json({
    success: true,
    data: {
      totalExpenses: data.totalExpenses,
      totalDebt: data.totalDebt,
      entries: data.entries,
    },
  });
});

const addMyExpense = asyncHandler(async (req, res) => {
  const { amount, description } = req.body;
  const entry = await addLedgerEntry(req.user._id, 'expense', amount, description, req.user);
  res.status(201).json({ success: true, data: entry });
});

const addMyDebt = asyncHandler(async (req, res) => {
  const { amount, description, supplierId } = req.body;
  const entry = await addLedgerEntry(
    req.user._id,
    'debt',
    amount,
    description,
    req.user,
    supplierId
  );
  res.status(201).json({ success: true, data: entry });
});

const getMyTreasury = asyncHandler(async (req, res) => {
  const data = await getEmployeeTreasurySummary(req.user._id);
  res.json({ success: true, data });
});

const getMyTreasuryStatement = asyncHandler(async (req, res) => {
  const data = await getEmployeeTreasuryStatement(req.user._id);
  res.json({ success: true, data });
});

module.exports = {
  getMyLedger,
  addMyExpense,
  addMyDebt,
  getMyTreasury,
  getMyTreasuryStatement,
};
