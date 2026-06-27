const Supplier = require('../models/Supplier');
const SupplierPayment = require('../models/SupplierPayment');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');
const { deductFromMainTreasury } = require('./treasuryService');

const createSupplierPayment = async (supplierId, data, user) => {
  const { paymentDate, amount, notes = '' } = data;

  if (!amount || amount <= 0) {
    throw new ApiError(400, 'Payment amount must be greater than zero');
  }

  const supplier = await Supplier.findById(supplierId);
  if (!supplier) throw new ApiError(404, 'Supplier not found');

  const balanceBefore = supplier.balance;
  if (amount > balanceBefore) {
    throw new ApiError(400, 'Payment amount cannot exceed supplier debt');
  }

  const balanceAfter = Math.max(0, balanceBefore - amount);

  const movement = await deductFromMainTreasury(amount, user, {
    reason: `دفع مورد — ${supplier.name}`,
    supplierId: supplier._id.toString(),
  });

  const payment = await SupplierPayment.create({
    supplierId,
    paymentDate: new Date(paymentDate),
    amount,
    balanceBefore,
    balanceAfter,
    notes,
    treasuryMovementId: movement._id,
    createdBy: user._id,
  });

  supplier.balance = balanceAfter;
  await supplier.save();

  await logAction(user._id, user.name, 'SUPPLIER_PAYMENT', supplier.name, { amount });

  return payment;
};

module.exports = { createSupplierPayment };
