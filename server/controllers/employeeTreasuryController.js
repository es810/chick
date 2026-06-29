const asyncHandler = require('../utils/asyncHandler');
const { transferEmployeeTreasury } = require('../services/employeeTreasuryService');

const createEmployeeTreasuryTransfer = asyncHandler(async (req, res) => {
  const { fromEmployeeId, toEmployeeId, amount, notes } = req.body;
  const transfer = await transferEmployeeTreasury(
    { fromEmployeeId, toEmployeeId, amount, notes },
    req.user
  );
  res.status(201).json({ success: true, data: transfer });
});

module.exports = { createEmployeeTreasuryTransfer };
