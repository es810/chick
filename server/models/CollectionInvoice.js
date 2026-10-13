const mongoose = require('mongoose');
const { receiptBalanceAfterCollection } = require('../utils/receiptBalances');

const collectionInvoiceSchema = new mongoose.Schema(
  {
    clientId: { type: mongoose.Schema.Types.ObjectId, ref: 'Client', required: true },
    employeeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    collectionDate: { type: Date, required: true },
    amountPaid: { type: Number, required: true, min: 0.01 },
    amountDeducted: { type: Number, required: true, min: 0, default: 0 },
    balanceBefore: { type: Number, required: true, min: 0 },
    balanceAfter: { type: Number, required: true, min: 0 },
    treasuryMovementId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'TreasuryMovement',
      required: true,
    },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    clientMutationId: { type: String, default: null, sparse: true },
  },
  { timestamps: true }
);

collectionInvoiceSchema.pre('validate', function applyReceiptBalances() {
  const before = Math.max(0, Number(this.balanceBefore) || 0);
  this.balanceBefore = before;
  this.balanceAfter = receiptBalanceAfterCollection({
    balanceBefore: before,
    amountPaid: this.amountPaid,
    amountDeducted: this.amountDeducted,
  });
});

collectionInvoiceSchema.index({ collectionDate: -1 });
collectionInvoiceSchema.index({ clientId: 1, collectionDate: -1 });
collectionInvoiceSchema.index(
  { clientMutationId: 1 },
  { unique: true, partialFilterExpression: { clientMutationId: { $type: 'string' } } }
);

module.exports = mongoose.model('CollectionInvoice', collectionInvoiceSchema);
