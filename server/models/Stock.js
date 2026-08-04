const mongoose = require('mongoose');

const stockSchema = new mongoose.Schema(
  {
    location: { type: String, trim: true, default: '' },
    chickenType: { type: String, required: true, trim: true, unique: true },
    quantity: { type: Number, required: true, min: 0, default: 0 },
    grossWeight: { type: Number, default: 0, min: 0 },
    tareWeight: { type: Number, default: 0, min: 0 },
    netWeight: { type: Number, default: 0, min: 0 },
    averageWeight: { type: Number, required: true, min: 0 },
    pricePerKg: { type: Number, required: true, min: 0 },
    totalAmount: { type: Number, default: 0, min: 0 },
    lowStockThreshold: { type: Number, default: 50 },
    /**
     * Oversold count/weight not yet written off (هلك).
     * Usable on-hand = book stock − these pending surpluses.
     */
    pendingSurplusQuantity: { type: Number, default: 0, min: 0 },
    pendingSurplusNetWeight: { type: Number, default: 0, min: 0 },
  },
  { timestamps: true, toJSON: { virtuals: true }, toObject: { virtuals: true } }
);

stockSchema.virtual('isLowStock').get(function () {
  return this.usableQuantity <= this.lowStockThreshold;
});

stockSchema.virtual('usableQuantity').get(function () {
  return Math.max(0, (this.quantity || 0) - (this.pendingSurplusQuantity || 0));
});

stockSchema.virtual('usableNetWeight').get(function () {
  return Math.max(0, (this.netWeight || 0) - (this.pendingSurplusNetWeight || 0));
});

module.exports = mongoose.model('Stock', stockSchema);
