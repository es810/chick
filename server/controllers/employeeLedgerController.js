const asyncHandler = require('../utils/asyncHandler');
const { getEmployeeLedger, addLedgerEntry } = require('../services/employeeLedgerService');

const getLedger = asyncHandler(async (req, res) => {
  const data = await getEmployeeLedger(req.params.id);
  res.json({
    success: true,
    data: {
      employee: data.employee,
      totalExpenses: data.totalExpenses,
      totalDebt: data.totalDebt,
      entries: data.entries,
    },
  });
});

const addExpense = asyncHandler(async (req, res) => {
  const { amount, description } = req.body;
  const entry = await addLedgerEntry(req.params.id, 'expense', amount, description, req.user);
  res.status(201).json({ success: true, data: entry });
});

const addDebt = asyncHandler(async (req, res) => {
  const { amount, description } = req.body;
  const entry = await addLedgerEntry(req.params.id, 'debt', amount, description, req.user);
  res.status(201).json({ success: true, data: entry });
});

module.exports = { getLedger, addExpense, addDebt };
