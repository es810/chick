const mongoose = require('mongoose');

const damagedStockSchema = new mongoose.Schema(
  {
    stockId: { type: mongoose.Schema.Types.ObjectId, ref: 'Stock', required: true },
    chickenType: { type: String, required: true, trim: true },
    quantity: { type: Number, required: true, min: 1 },
    reason: { type: String, trim: true, default: '' },
    recordedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

damagedStockSchema.index({ createdAt: -1 });
damagedStockSchema.index({ stockId: 1 });

module.exports = mongoose.model('DamagedStock', damagedStockSchema);
