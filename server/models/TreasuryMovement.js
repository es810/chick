const mongoose = require('mongoose');

const treasuryMovementSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ['external_revenue', 'withdrawal'],
      required: true,
    },
    amount: { type: Number, required: true, min: 0 },
    description: { type: String, default: '', trim: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

treasuryMovementSchema.index({ type: 1, createdAt: -1 });

module.exports = mongoose.model('TreasuryMovement', treasuryMovementSchema);
