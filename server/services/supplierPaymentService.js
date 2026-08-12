const Supplier = require('../models/Supplier');
const SupplierPayment = require('../models/SupplierPayment');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');
const { deductFromMainTreasury } = require('./treasuryService');

const createSupplierPayment = async (supplierId, data, user) => {
  const { paymentDate, amount, notes = '' } = data;
  const amountDeducted = Number(data.amountDeducted) || 0;

  if (!amount || amount <= 0) {
    throw new ApiError(400, 'Payment amount must be greater than zero');
  }
  if (amountDeducted < 0) {
    throw new ApiError(400, 'Deducted amount cannot be negative');
  }

  const supplier = await Supplier.findById(supplierId);
  if (!supplier) throw new ApiError(404, 'Supplier not found');

  const balanceBefore = supplier.balance;
  if (amount + amountDeducted > balanceBefore) {
    throw new ApiError(400, 'Payment and discount cannot exceed supplier debt');
  }

  const balanceAfter = Math.max(0, balanceBefore - amount - amountDeducted);

  const movement = await deductFromMainTreasury(amount, user, {
    reason: `دفع مورد — ${supplier.name}`,
    supplierId: supplier._id.toString(),
  });

  const payment = await SupplierPayment.create({
    supplierId,
    paymentDate: new Date(paymentDate),
    amount,
    amountDeducted,
    balanceBefore,
    balanceAfter,
    notes,
    treasuryMovementId: movement._id,
    createdBy: user._id,
  });

  supplier.balance = balanceAfter;
  await supplier.save();

  await logAction(user._id, user.name, 'SUPPLIER_PAYMENT', supplier.name, {
    amount,
    amountDeducted,
  });

  return payment;
};

module.exports = { createSupplierPayment };
