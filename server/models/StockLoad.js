const mongoose = require('mongoose');

/**
 * One load (حمولة) under قيد التهليك until distribution finishes.
 * Stock per chickenType stays aggregated; loads track FIFO write-off sessions.
 */
const stockLoadSchema = new mongoose.Schema(
  {
    stockId: { type: mongoose.Schema.Types.ObjectId, ref: 'Stock', required: true },
    chickenType: { type: String, required: true, trim: true },
    loadedQuantity: { type: Number, required: true, min: 0, default: 0 },
    loadedNetWeight: { type: Number, required: true, min: 0, default: 0 },
    remainingQuantity: { type: Number, required: true, min: 0, default: 0 },
    remainingNetWeight: { type: Number, required: true, min: 0, default: 0 },
    status: {
      type: String,
      enum: ['open', 'pending_writeoff', 'closed'],
      default: 'open',
    },
    damagedStockId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'DamagedStock',
      default: null,
    },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

stockLoadSchema.index({ chickenType: 1, status: 1, createdAt: 1 });
stockLoadSchema.index({ stockId: 1, status: 1 });
stockLoadSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model('StockLoad', stockLoadSchema);
