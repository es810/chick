const asyncHandler = require('../utils/asyncHandler');
const ApiError = require('../utils/apiError');
const { getEmployeeLedger, addLedgerEntry } = require('../services/employeeLedgerService');
const {
  getEmployeeTreasurySummary,
  getEmployeeTreasuryStatement,
  transferEmployeeTreasury,
} = require('../services/employeeTreasuryService');
const { hasPermission } = require('../utils/employeePermissions');

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
  if (!hasPermission(req.user, 'canAddExpense')) {
    throw new ApiError(403, 'Expenses are disabled for this employee');
  }
  const { amount, description, clientMutationId } = req.body;
  const entry = await addLedgerEntry(
    req.user._id,
    'expense',
    amount,
    description,
    req.user,
    null,
    0,
    clientMutationId
  );
  res.status(201).json({ success: true, data: entry });
});

const addMyDebt = asyncHandler(async (req, res) => {
  if (!hasPermission(req.user, 'canPaySupplier')) {
    throw new ApiError(403, 'Supplier payments are disabled for this employee');
  }
  const { amount, description, supplierId, amountDeducted = 0 } = req.body;
  const entry = await addLedgerEntry(
    req.user._id,
    'debt',
    amount,
    description,
    req.user,
    supplierId,
    amountDeducted
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

const transferMyTreasury = asyncHandler(async (req, res) => {
  if (!hasPermission(req.user, 'canTransfer')) {
    throw new ApiError(403, 'Transfers are disabled for this employee');
  }
  const { toEmployeeId, amount, notes } = req.body;
  const transfer = await transferEmployeeTreasury(
    {
      fromEmployeeId: req.user._id.toString(),
      toEmployeeId,
      amount,
      notes,
    },
    req.user
  );
  res.status(201).json({ success: true, data: transfer });
});

module.exports = {
  getMyLedger,
  addMyExpense,
  addMyDebt,
  getMyTreasury,
  getMyTreasuryStatement,
  transferMyTreasury,
};
