const mongoose = require('mongoose');

const supplierSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    location: { type: String, default: '', trim: true },
    phone: { type: String, required: true, trim: true },
  },
  { timestamps: true }
);

supplierSchema.index({ name: 'text', phone: 'text', location: 'text' });

module.exports = mongoose.model('Supplier', supplierSchema);
