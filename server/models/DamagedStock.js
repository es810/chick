const mongoose = require('mongoose');

const damagedStockSchema = new mongoose.Schema(
  {
    stockId: { type: mongoose.Schema.Types.ObjectId, ref: 'Stock', required: true },
    chickenType: { type: String, required: true, trim: true },
    /** Bird count when known; may be 0 for weight-only surplus. */
    quantity: { type: Number, required: true, min: 0, default: 0 },
    /** Weight in kg (surplus from distribution or written-off weight). */
    netWeight: { type: Number, required: true, min: 0, default: 0 },
    reason: { type: String, trim: true, default: '' },
    source: {
      type: String,
      enum: ['manual', 'distribution_surplus', 'distribution_remainder'],
      default: 'manual',
    },
    /**
     * open = needs تأكيد الهلاك (surplus still reduces usable stock;
     *        remainder is already off the books but awaiting confirmation).
     * written_off = settled.
     */
    status: {
      type: String,
      enum: ['open', 'written_off'],
      default: 'open',
    },
    invoiceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Invoice', default: null },
    recordedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

damagedStockSchema.index({ createdAt: -1 });
damagedStockSchema.index({ stockId: 1 });
damagedStockSchema.index({ invoiceId: 1 });
damagedStockSchema.index({ status: 1, source: 1 });

module.exports = mongoose.model('DamagedStock', damagedStockSchema);
