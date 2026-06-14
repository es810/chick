const mongoose = require('mongoose');

const collectionInvoiceSchema = new mongoose.Schema(
  {
    clientId: { type: mongoose.Schema.Types.ObjectId, ref: 'Client', required: true },
    employeeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    collectionDate: { type: Date, required: true },
    amountPaid: { type: Number, required: true, min: 0.01 },
    amountDeducted: { type: Number, required: true, min: 0.01 },
    balanceBefore: { type: Number, required: true, min: 0 },
    balanceAfter: { type: Number, required: true, min: 0 },
    treasuryMovementId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'TreasuryMovement',
      required: true,
    },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

collectionInvoiceSchema.index({ collectionDate: -1 });
collectionInvoiceSchema.index({ clientId: 1, collectionDate: -1 });

module.exports = mongoose.model('CollectionInvoice', collectionInvoiceSchema);
