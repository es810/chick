const Supplier = require('../models/Supplier');
const SupplierPayment = require('../models/SupplierPayment');
const ApiError = require('../utils/apiError');
const { addLedgerEntry } = require('./employeeLedgerService');

/**
 * Supplier payments always flow through the paying employee's treasury
 * (employee ledger debt), which also reduces the main treasury via loading.
 */
const createSupplierPayment = async (supplierId, data, user) => {
  const { paymentDate, amount, notes = '' } = data;
  const amountDeducted = Number(data.amountDeducted) || 0;
  const employeeId =
    user.role === 'employee' ? user._id.toString() : data.employeeId?.toString();

  if (!amount || amount <= 0) {
    throw new ApiError(400, 'Payment amount must be greater than zero');
  }
  if (amountDeducted < 0) {
    throw new ApiError(400, 'Deducted amount cannot be negative');
  }
  if (!employeeId) {
    throw new ApiError(400, 'Employee is required for supplier payment');
  }

  const supplier = await Supplier.findById(supplierId);
  if (!supplier) throw new ApiError(404, 'Supplier not found');

  if (amount + amountDeducted > (supplier.balance || 0)) {
    throw new ApiError(400, 'Payment and discount cannot exceed supplier debt');
  }

  const description = notes.trim() || `دفع مورد — ${supplier.name}`;

  const entry = await addLedgerEntry(
    employeeId,
    'debt',
    amount,
    description,
    user,
    supplierId,
    amountDeducted
  );

  const payment = await SupplierPayment.findOne({ employeeLedgerId: entry._id });
  if (!payment) throw new ApiError(500, 'Supplier payment not recorded');

  if (paymentDate) {
    const paidAt = new Date(paymentDate);
    if (!Number.isNaN(paidAt.getTime())) {
      payment.paymentDate = paidAt;
      await payment.save();
    }
  }

  return payment;
};

module.exports = { createSupplierPayment };
