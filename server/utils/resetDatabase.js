const mongoose = require('mongoose');
const User = require('../models/User');
const Client = require('../models/Client');
const Supplier = require('../models/Supplier');
const SupplierStock = require('../models/SupplierStock');
const Stock = require('../models/Stock');
const StockMovement = require('../models/StockMovement');
const Invoice = require('../models/Invoice');
const CollectionInvoice = require('../models/CollectionInvoice');
const DamagedStock = require('../models/DamagedStock');
const Treasury = require('../models/Treasury');
const TreasuryMovement = require('../models/TreasuryMovement');
const EmployeeLedger = require('../models/EmployeeLedger');
const SalaryAdvance = require('../models/SalaryAdvance');
const SupplierPayment = require('../models/SupplierPayment');
const AuditLog = require('../models/AuditLog');
const { bootstrapInitialAdmin } = require('./bootstrapAdmin');

const COLLECTIONS = [
  AuditLog,
  SalaryAdvance,
  SupplierPayment,
  EmployeeLedger,
  TreasuryMovement,
  CollectionInvoice,
  DamagedStock,
  StockMovement,
  Invoice,
  Stock,
  SupplierStock,
  Supplier,
  Client,
  User,
  Treasury,
];

const resetDatabase = async ({ bootstrap = true } = {}) => {
  for (const Model of COLLECTIONS) {
    await Model.deleteMany({});
  }

  if (bootstrap) {
    await bootstrapInitialAdmin();
  }
};

const runCli = async () => {
  require('../config/mongoDns');
  require('dotenv').config();
  const { mongoUri } = require('../config/env');
  await mongoose.connect(mongoUri);
  console.log('Connected — wiping all application data...');
  await resetDatabase({ bootstrap: true });
  const users = await User.countDocuments();
  console.log(users > 0 ? '\nDatabase reset. Initial admin is ready.\n' : '\nDatabase reset. Set INITIAL_ADMIN_EMAIL and INITIAL_ADMIN_PASSWORD, then run again or restart the server.\n');
  await mongoose.disconnect();
  process.exit(0);
};

if (require.main === module) {
  runCli().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}

module.exports = { resetDatabase };
