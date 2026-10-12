/**
 * One-shot: set each distribution invoice
 *   balanceAfter = balanceBefore + meal  (or balanceBefore if paid)
 * Usage (from server/): node scripts/repairInvoiceBalanceAfter.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const Invoice = require('../models/Invoice');

async function main() {
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI is required');
  await mongoose.connect(uri);

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
      console.log(`${inv.invoiceNumber}: ${current} → ${expected}`);
    }
  }
  console.log(`Done. Updated ${changed}/${invoices.length} invoices.`);
  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
