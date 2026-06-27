const mongoose = require('mongoose');

const supplierPaymentSchema = new mongoose.Schema(
  {
    supplierId: { type: mongoose.Schema.Types.ObjectId, ref: 'Supplier', required: true },
    paymentDate: { type: Date, required: true },
    amount: { type: Number, required: true, min: 0.01 },
    balanceBefore: { type: Number, required: true, min: 0 },
    balanceAfter: { type: Number, required: true, min: 0 },
    notes: { type: String, default: '', trim: true },
    treasuryMovementId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'TreasuryMovement',
      required: true,
    },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

supplierPaymentSchema.index({ supplierId: 1, paymentDate: -1 });

module.exports = mongoose.model('SupplierPayment', supplierPaymentSchema);
