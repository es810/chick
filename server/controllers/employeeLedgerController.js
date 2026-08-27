const asyncHandler = require('../utils/asyncHandler');
const { getEmployeeLedger, addLedgerEntry } = require('../services/employeeLedgerService');
const { listEmployeeAdvances, createSalaryAdvance } = require('../services/salaryAdvanceService');
const { getEmployeeTreasurySummary, getEmployeeTreasuryStatement } = require('../services/employeeTreasuryService');

const getLedger = asyncHandler(async (req, res) => {
  const [ledger, advanceData, treasury] = await Promise.all([
    getEmployeeLedger(req.params.id),
    listEmployeeAdvances(req.params.id),
    getEmployeeTreasurySummary(req.params.id),
  ]);

  res.json({
    success: true,
    data: {
      employee: ledger.employee,
      totalExpenses: ledger.totalExpenses,
      totalDebt: ledger.totalDebt,
      entries: ledger.entries,
      totalAdvances: advanceData.totalAdvances,
      advances: advanceData.advances,
      treasuryBalance: treasury.balance,
      treasury: {
        balance: treasury.balance,
        collection: treasury.collection,
        incomingTransfer: treasury.incomingTransfer,
        expenses: treasury.expenses,
        advances: treasury.advances,
        debts: treasury.debts,
        outgoingTransfer: treasury.outgoingTransfer,
      },
    },
  });
});

const addExpense = asyncHandler(async (req, res) => {
  const { amount, description } = req.body;
  const entry = await addLedgerEntry(req.params.id, 'expense', amount, description, req.user);
  res.status(201).json({ success: true, data: entry });
});

const addDebt = asyncHandler(async (req, res) => {
  const { amount, description, supplierId, amountDeducted = 0 } = req.body;
  const entry = await addLedgerEntry(
    req.params.id,
    'debt',
    amount,
    description,
    req.user,
    supplierId,
    amountDeducted
  );
  res.status(201).json({ success: true, data: entry });
});

const addSalaryAdvance = asyncHandler(async (req, res) => {
  const { advanceDate, amount, notes } = req.body;
  const advance = await createSalaryAdvance(
    req.params.id,
    { advanceDate, amount, notes },
    req.user
  );
  res.status(201).json({ success: true, data: advance });
});

const getTreasuryStatement = asyncHandler(async (req, res) => {
  const data = await getEmployeeTreasuryStatement(req.params.id);
  res.json({ success: true, data });
});

module.exports = { getLedger, addExpense, addDebt, addSalaryAdvance, getTreasuryStatement };
