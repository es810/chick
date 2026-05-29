const mongoose = require('mongoose');

const treasurySchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true, default: 'main' },
    openingBalance: { type: Number, default: 0 },
    balance: { type: Number, default: 0 },
    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Treasury', treasurySchema);
