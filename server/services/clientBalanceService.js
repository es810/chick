const mongoose = require('mongoose');
const Client = require('../models/Client');
const Invoice = require('../models/Invoice');
const CollectionInvoice = require('../models/CollectionInvoice');

const runInSession = (query, session) => (session ? query.session(session) : query);

const getLedgerTotals = async (clientId, session = null) => {
  const id =
    clientId instanceof mongoose.Types.ObjectId
      ? clientId
      : new mongoose.Types.ObjectId(String(clientId));

  const invoicesQuery = Invoice.aggregate([
    { $match: { clientId: id, paymentStatus: { $ne: 'paid' } } },
    { $group: { _id: null, total: { $sum: '$totalPrice' } } },
  ]);
  const collectionsQuery = CollectionInvoice.aggregate([
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
    invoicesQuery.session(session);
    collectionsQuery.session(session);
  }

  const [invoices, collections] = await Promise.all([
    invoicesQuery,
    collectionsQuery,
  ]);
  return {
    id,
    unpaid: invoices[0]?.total || 0,
    collected: collections[0]?.total || 0,
  };
};

/**
 * Persist the opening debt before a transaction changes the ledger. For
 * legacy clients, recover it from the current balance and, when available, the
 * first receipt's saved balanceBefore snapshot.
 */
const ensureClientOpeningBalance = async (clientOrId, session = null) => {
  let client = clientOrId;
  if (!client || typeof client.save !== 'function') {
    const query = Client.findById(clientOrId);
    client = await runInSession(query, session);
  }
  if (!client) return null;
  if (client.openingBalance != null && Number.isFinite(Number(client.openingBalance))) {
    return client;
  }

  const { id, unpaid, collected } = await getLedgerTotals(client._id, session);
  const ledgerBalance = unpaid - collected;
  const inferredOpening = Math.max(0, (Number(client.balance) || 0) - ledgerBalance);

  const invoiceQuery = Invoice.findOne({ clientId: id })
    .sort({ createdAt: 1 })
    .select('createdAt balanceBefore')
    .lean();
  const collectionQuery = CollectionInvoice.findOne({ clientId: id })
    .sort({ createdAt: 1 })
    .select('createdAt balanceBefore')
    .lean();
  const [firstInvoice, firstCollection] = await Promise.all([
    runInSession(invoiceQuery, session),
    runInSession(collectionQuery, session),
  ]);
  const firstReceipt = [firstInvoice, firstCollection]
    .filter(Boolean)
    .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt))[0];
  const receiptOpening = Math.max(0, Number(firstReceipt?.balanceBefore) || 0);

  client.openingBalance = Math.max(inferredOpening, receiptOpening);
  if (session) await client.save({ session });
  else await client.save();
  return client;
};

/** Rebuild the live balance while retaining the separately stored opening debt. */
const syncClientBalanceFromLedger = async (clientId, session = null) => {
  if (!clientId) return 0;
  const id =
    clientId instanceof mongoose.Types.ObjectId
      ? clientId
      : new mongoose.Types.ObjectId(String(clientId));

  const client = await ensureClientOpeningBalance(id, session);
  if (!client) return 0;

  const { unpaid, collected } = await getLedgerTotals(id, session);
  const balance = Math.max(
    0,
    (Number(client.openingBalance) || 0) + unpaid - collected
  );
  client.balance = balance;
  if (session) await client.save({ session });
  else await client.save();
  return balance;
};

/** Treat an explicit client edit as a new total balance, adjusting the opening debt. */
const setClientBalance = async (clientOrId, newBalance) => {
  const client = await ensureClientOpeningBalance(clientOrId);
  if (!client) return null;
  const { unpaid, collected } = await getLedgerTotals(client._id);
  const requested = Math.max(0, Number(newBalance) || 0);
  client.openingBalance = Math.max(0, requested - unpaid + collected);
  client.balance = requested;
  await client.save();
  return client;
};

module.exports = {
  ensureClientOpeningBalance,
  setClientBalance,
  syncClientBalanceFromLedger,
};
