const mongoose = require('mongoose');

const supplierPaymentSchema = new mongoose.Schema(
  {
    supplierId: { type: mongoose.Schema.Types.ObjectId, ref: 'Supplier', required: true },
    paymentDate: { type: Date, required: true },
    amount: { type: Number, required: true, min: 0.01 },
    balanceBefore: { type: Number, required: true, min: 0 },
    balanceAfter: { type: Number, required: true, min: 0 },
    notes: { type: String, default: '', trim: true },
    /** Set when paid from main treasury withdrawal (admin pay-debt). */
    treasuryMovementId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'TreasuryMovement',
      default: null,
    },
    /** Set when paid via employee goods-debt / loading entry. */
    employeeLedgerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'EmployeeLedger',
      default: null,
    },
    employeeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

supplierPaymentSchema.index({ supplierId: 1, paymentDate: -1 });
supplierPaymentSchema.index({ employeeLedgerId: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model('SupplierPayment', supplierPaymentSchema);
