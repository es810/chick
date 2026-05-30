const mongoose = require('mongoose');

const stockMovementSchema = new mongoose.Schema(
  {
    type: { type: String, enum: ['IN', 'OUT'], required: true },
    stockId: { type: mongoose.Schema.Types.ObjectId, ref: 'Stock', required: true },
    chickenType: { type: String, required: true },
    quantity: { type: Number, required: true, min: 1 },
    location: { type: String, trim: true, default: '' },
    grossWeight: { type: Number, default: 0, min: 0 },
    tareWeight: { type: Number, default: 0, min: 0 },
    netWeight: { type: Number, default: 0, min: 0 },
    unitPrice: { type: Number, default: 0, min: 0 },
    totalAmount: { type: Number, default: 0, min: 0 },
    reason: { type: String, required: true },
    invoiceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Invoice' },
    employeeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

stockMovementSchema.index({ createdAt: -1 });
stockMovementSchema.index({ stockId: 1 });

module.exports = mongoose.model('StockMovement', stockMovementSchema);
