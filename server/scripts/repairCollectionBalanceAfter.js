/**
 * One-shot: set each collection invoice balanceAfter = before − paid − discount.
 * Usage (from server/): node scripts/repairCollectionBalanceAfter.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const CollectionInvoice = require('../models/CollectionInvoice');

async function main() {
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI is required');
  await mongoose.connect(uri);

  const invoices = await CollectionInvoice.find().select(
    'amountPaid amountDeducted balanceBefore balanceAfter'
  );
  let changed = 0;
  for (const inv of invoices) {
    const before = Number(inv.balanceBefore) || 0;
    const paid = Number(inv.amountPaid) || 0;
    const deducted = Number(inv.amountDeducted) || 0;
    const expected = Math.max(0, before - paid - deducted);
    const current = Number(inv.balanceAfter);
    if (!Number.isFinite(current) || Math.abs(current - expected) > 0.001) {
      inv.balanceAfter = expected;
      await inv.save();
      changed += 1;
      console.log(`${inv._id}: ${current} → ${expected}`);
    }
  }
  console.log(`Done. Updated ${changed}/${invoices.length} collection invoices.`);
  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
