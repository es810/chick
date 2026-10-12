const mongoose = require('mongoose');
const Invoice = require('../models/Invoice');
const logger = require('./logger');

const FLAG = 'invoice_receipt_balance_after_v1';

/**
 * One-time: receipt «مستحق بعد» = prior debt + meal (or prior if paid).
 * Does not change client.balance. Idempotent via app_meta flag.
 */
const repairInvoiceReceiptBalances = async () => {
  try {
    const meta = mongoose.connection.collection('app_meta');
    const already = await meta.findOne({ key: FLAG });
    if (already) return;

    const invoices = await Invoice.find().select(
      'invoiceNumber totalPrice paymentStatus balanceBefore balanceAfter'
    );
    let changed = 0;
    for (const inv of invoices) {
      const before = Number(inv.balanceBefore) || 0;
      const meal = Number(inv.totalPrice) || 0;
      const expected =
        inv.paymentStatus === 'paid' ? before : Math.max(0, before + meal);
      const current = Number(inv.balanceAfter);
      if (!Number.isFinite(current) || Math.abs(current - expected) > 0.001) {
        inv.balanceAfter = expected;
        await inv.save();
        changed += 1;
      }
    }

    await meta.updateOne(
      { key: FLAG },
      { $set: { key: FLAG, repairedAt: new Date(), changed } },
      { upsert: true }
    );
    logger.info(`Invoice receipt balances repaired: ${changed}/${invoices.length}`);
  } catch (error) {
    logger.warn(`Invoice receipt balance repair skipped: ${error.message}`);
  }
};

module.exports = { repairInvoiceReceiptBalances };
