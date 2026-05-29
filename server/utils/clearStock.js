require('dotenv').config();
const mongoose = require('mongoose');
const Stock = require('../models/Stock');
const StockMovement = require('../models/StockMovement');
const { mongoUri } = require('../config/env');

const clearStock = async () => {
  await mongoose.connect(mongoUri);
  const [stockResult, movementResult] = await Promise.all([
    Stock.deleteMany(),
    StockMovement.deleteMany(),
  ]);
  console.log(`Removed ${stockResult.deletedCount} stock item(s) and ${movementResult.deletedCount} movement(s).`);
  process.exit(0);
};

clearStock().catch((err) => {
  console.error(err);
  process.exit(1);
});
