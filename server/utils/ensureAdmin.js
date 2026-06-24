require('dotenv').config();
const mongoose = require('mongoose');
const { mongoUri } = require('../config/env');
const { ensureAdminFromEnv } = require('./bootstrapAdmin');

const run = async () => {
  await mongoose.connect(mongoUri);
  const result = await ensureAdminFromEnv();
  console.log(`\nAdmin ${result.action}: ${result.email}\n`);
  await mongoose.disconnect();
  process.exit(0);
};

run().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
