const mongoose = require('mongoose');

const clientSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    phone: { type: String, required: true, trim: true },
    address: { type: String, default: '' },
    balance: { type: Number, default: 0, min: 0 },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

clientSchema.index({ name: 'text', phone: 'text' });

module.exports = mongoose.model('Client', clientSchema);
