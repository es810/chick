const mongoose = require('mongoose');

const stockSchema = new mongoose.Schema(
  {
    chickenType: { type: String, required: true, trim: true, unique: true },
    quantity: { type: Number, required: true, min: 0, default: 0 },
    averageWeight: { type: Number, required: true, min: 0 },
    pricePerKg: { type: Number, required: true, min: 0 },
    lowStockThreshold: { type: Number, default: 50 },
  },
  { timestamps: true }
);

stockSchema.virtual('isLowStock').get(function () {
  return this.quantity <= this.lowStockThreshold;
});

module.exports = mongoose.model('Stock', stockSchema);
