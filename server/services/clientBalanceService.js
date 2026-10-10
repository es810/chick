const mongoose = require('mongoose');
const Client = require('../models/Client');
const Invoice = require('../models/Invoice');
const CollectionInvoice = require('../models/CollectionInvoice');

/**
 * Rebuild client.balance from open distribution invoices minus all collections.
 * Prevents «مديونية سابقة» ghosts after edits that used reverse+clamp.
 */
const syncClientBalanceFromLedger = async (clientId, session = null) => {
  if (!clientId) return 0;
  const id =
    clientId instanceof mongoose.Types.ObjectId
      ? clientId
      : new mongoose.Types.ObjectId(String(clientId));

  const invQuery = Invoice.aggregate([
    { $match: { clientId: id, paymentStatus: { $ne: 'paid' } } },
    { $group: { _id: null, total: { $sum: '$totalPrice' } } },
  ]);
  const colQuery = CollectionInvoice.aggregate([
    { $match: { clientId: id } },
    {
      $group: {
        _id: null,
        total: {
          $sum: { $add: ['$amountPaid', { $ifNull: ['$amountDeducted', 0] }] },
        },
      },
    },
  ]);

  if (session) {
    invQuery.session(session);
    colQuery.session(session);
  }

  const [invAgg, colAgg] = await Promise.all([invQuery, colQuery]);
  const unpaid = invAgg[0]?.total || 0;
  const collected = colAgg[0]?.total || 0;
  const balance = Math.max(0, unpaid - collected);

  const update = Client.updateOne({ _id: id }, { $set: { balance } });
  if (session) update.session(session);
  await update;

  return balance;
};

module.exports = { syncClientBalanceFromLedger };
