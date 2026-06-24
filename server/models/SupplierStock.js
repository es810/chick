const mongoose = require('mongoose');

const supplierStockSchema = new mongoose.Schema(
  {
    supplierId: { type: mongoose.Schema.Types.ObjectId, ref: 'Supplier', required: true },
    location: { type: String, trim: true, default: '' },
    chickenType: { type: String, required: true, trim: true },
    quantity: { type: Number, required: true, min: 0, default: 0 },
    grossWeight: { type: Number, default: 0, min: 0 },
    tareWeight: { type: Number, default: 0, min: 0 },
    netWeight: { type: Number, default: 0, min: 0 },
    averageWeight: { type: Number, required: true, min: 0 },
    pricePerKg: { type: Number, required: true, min: 0 },
    totalAmount: { type: Number, default: 0, min: 0 },
    lowStockThreshold: { type: Number, default: 50 },
  },
  { timestamps: true }
);

supplierStockSchema.index({ supplierId: 1, chickenType: 1 }, { unique: true });
supplierStockSchema.virtual('isLowStock').get(function () {
  return this.quantity <= this.lowStockThreshold;
});

module.exports = mongoose.model('SupplierStock', supplierStockSchema);
