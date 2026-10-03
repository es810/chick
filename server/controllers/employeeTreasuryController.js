const asyncHandler = require('../utils/asyncHandler');
const { transferEmployeeTreasury } = require('../services/employeeTreasuryService');

const createEmployeeTreasuryTransfer = asyncHandler(async (req, res) => {
  const { fromEmployeeId, toEmployeeId, amount, notes, clientMutationId } = req.body;
  const transfer = await transferEmployeeTreasury(
    { fromEmployeeId, toEmployeeId, amount, notes, clientMutationId },
    req.user
  );
  res.status(201).json({ success: true, data: transfer });
});

module.exports = { createEmployeeTreasuryTransfer };
