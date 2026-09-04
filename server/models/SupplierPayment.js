const mongoose = require('mongoose');

const supplierPaymentSchema = new mongoose.Schema(
  {
    supplierId: { type: mongoose.Schema.Types.ObjectId, ref: 'Supplier', required: true },
    paymentDate: { type: Date, required: true },
    amount: { type: Number, required: true, min: 0.01 },
    /** Extra discount off supplier debt — does not leave the treasury. */
    amountDeducted: { type: Number, required: true, min: 0, default: 0 },
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
    },
    employeeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

supplierPaymentSchema.index({ supplierId: 1, paymentDate: -1 });
// Only enforce uniqueness when a real ledger link exists (ignore missing/null).
supplierPaymentSchema.index(
  { employeeLedgerId: 1 },
  {
    unique: true,
    partialFilterExpression: { employeeLedgerId: { $exists: true, $type: 'objectId' } },
  }
);
module.exports = mongoose.model('SupplierPayment', supplierPaymentSchema);
