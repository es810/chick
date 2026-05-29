const mongoose = require('mongoose');

const invoiceItemSchema = new mongoose.Schema(
  {
    chickenType: { type: String, required: true },
    stockId: { type: mongoose.Schema.Types.ObjectId, ref: 'Stock' },
    quantity: { type: Number, required: true, min: 1 },
    weight: { type: Number, required: true, min: 0 },
    unitPrice: { type: Number, required: true, min: 0 },
    total: { type: Number, required: true, min: 0 },
  },
  { _id: false }
);

const invoiceSchema = new mongoose.Schema(
  {
    invoiceNumber: { type: String, required: true, unique: true },
    clientId: { type: mongoose.Schema.Types.ObjectId, ref: 'Client', required: true },
    employeeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    items: { type: [invoiceItemSchema], required: true, validate: [(v) => v.length > 0, 'Items required'] },
    itemCount: { type: Number, default: 1, min: 1 },
    grossWeight: { type: Number, min: 0 },
    tareWeight: { type: Number, default: 0, min: 0 },
    totalWeight: { type: Number, required: true, min: 0 },
    totalPrice: { type: Number, required: true, min: 0 },
    balanceBefore: { type: Number, min: 0 },
    balanceAfter: { type: Number, min: 0 },
    paymentStatus: {
      type: String,
      enum: ['pending', 'partial', 'paid'],
      default: 'pending',
    },
    notes: { type: String, default: '' },
  },
  { timestamps: true }
);

invoiceSchema.index({ createdAt: -1 });
invoiceSchema.index({ clientId: 1 });
invoiceSchema.index({ employeeId: 1 });

module.exports = mongoose.model('Invoice', invoiceSchema);
