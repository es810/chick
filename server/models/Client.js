const mongoose = require('mongoose');

const clientSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    phone: { type: String, required: true, trim: true },
    address: { type: String, default: '' },
    /** Invite/open link for the client's WhatsApp group (chat.whatsapp.com/...) */
    whatsappGroupLink: { type: String, default: '', trim: true },
    balance: { type: Number, default: 0, min: 0 },
    // Nullable for existing clients; initialized from their ledger before the
    // first edit/delete so opening debt survives ledger rebuilds.
    openingBalance: { type: Number, default: null, min: 0 },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

clientSchema.index({ name: 'text', phone: 'text' });

module.exports = mongoose.model('Client', clientSchema);
