/**
 * One-shot: rebuild every client.balance from unpaid invoices − collections.
 * Usage (from server/): node scripts/repairClientBalances.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const Client = require('../models/Client');
const { syncClientBalanceFromLedger } = require('../services/clientBalanceService');

async function main() {
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI is required');
  await mongoose.connect(uri);

  const clients = await Client.find().select('_id name balance');
  let changed = 0;
  for (const c of clients) {
    const before = c.balance || 0;
    const after = await syncClientBalanceFromLedger(c._id);
    if (Math.abs(before - after) > 0.001) {
      changed += 1;
      console.log(`${c.name}: ${before} → ${after}`);
    }
  }
  console.log(`Done. Updated ${changed}/${clients.length} clients.`);
  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
