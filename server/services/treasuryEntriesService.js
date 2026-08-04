const TreasuryMovement = require('../models/TreasuryMovement');
const EmployeeLedger = require('../models/EmployeeLedger');
const User = require('../models/User');
const ApiError = require('../utils/apiError');
const { getTreasurySummary } = require('./treasuryService');
const { addLedgerEntry } = require('./employeeLedgerService');

const { listCollectionInvoices } = require('./collectionInvoiceService');

const listMovements = async (type) => {
  const movements = await TreasuryMovement.find({ type })
    .populate('createdBy', 'name')
    .sort({ createdAt: -1 });

  return movements.map((m) => ({
    id: m._id,
    category: type,
    amount: m.amount,
    description: m.description,
    subtitle: m.createdBy?.name ?? '',
    createdAt: m.createdAt,
  }));
};

const listLedgerEntries = async (type) => {
  const entries = await EmployeeLedger.find({ type })
    .populate('employeeId', 'name')
    .populate('createdBy', 'name')
    .populate('supplierId', 'name')
    .sort({ createdAt: -1 });

  return entries.map((e) => ({
    id: e._id,
    category: type === 'debt' ? 'loading' : 'expense',
    amount: e.amount,
    description: e.description,
    subtitle: e.employeeId?.name ?? '',
    createdAt: e.createdAt,
  }));
};

const createMovement = async (type, amount, description, user) => {
  if (!amount || amount <= 0) throw new ApiError(400, 'Amount must be greater than zero');

  if (type === 'withdrawal') {
    const summary = await getTreasurySummary();
    if (summary.balance < amount) {
      throw new ApiError(400, 'Insufficient main treasury balance');
    }
  }

  const movement = await TreasuryMovement.create({
    type,
    amount,
    description: description || (type === 'collection' ? 'تحصيل' : type === 'external_revenue' ? 'إيراد خارجي' : 'سحب'),
    createdBy: user._id,
  });

  return {
    id: movement._id,
    category: type,
    amount: movement.amount,
    description: movement.description,
    subtitle: user.name,
    createdAt: movement.createdAt,
  };
};

const updateMovement = async (id, { amount, description }) => {
  const movement = await TreasuryMovement.findById(id);
  if (!movement) throw new ApiError(404, 'Entry not found');

  if (amount != null) {
    if (amount <= 0) throw new ApiError(400, 'Amount must be greater than zero');
    movement.amount = amount;
  }
  if (description != null) movement.description = description;
  await movement.save();

  return movement;
};

const deleteMovement = async (id) => {
  const movement = await TreasuryMovement.findByIdAndDelete(id);
  if (!movement) throw new ApiError(404, 'Entry not found');
  return movement;
};

const createLedgerEntry = async (type, employeeId, amount, description, user) => {
  const ledgerType = type === 'loading' ? 'debt' : 'expense';
  const entry = await addLedgerEntry(employeeId, ledgerType, amount, description, user);
  await entry.populate('employeeId', 'name');
  await entry.populate('createdBy', 'name');

  return {
    id: entry._id,
    category: type,
    amount: entry.amount,
    description: entry.description,
    subtitle: entry.employeeId?.name ?? '',
    createdAt: entry.createdAt,
  };
};

const updateLedgerEntry = async (id, { amount, description }) => {
  const entry = await EmployeeLedger.findById(id);
  if (!entry) throw new ApiError(404, 'Entry not found');

  const oldAmount = entry.amount;
  if (amount != null) {
    if (amount <= 0) throw new ApiError(400, 'Amount must be greater than zero');
    if (amount > oldAmount) {
      const summary = await getTreasurySummary();
      const delta = amount - oldAmount;
      if (summary.balance < delta) {
        throw new ApiError(400, 'Insufficient main treasury balance');
      }
    }
    entry.amount = amount;
  }
  if (description != null) entry.description = description;
  await entry.save();
  return entry;
};

const deleteLedgerEntry = async (id) => {
  const entry = await EmployeeLedger.findByIdAndDelete(id);
  if (!entry) throw new ApiError(404, 'Entry not found');
  return entry;
};

const listEmployeesForPicker = async () => {
  return User.find({ role: 'employee', isActive: { $ne: false } })
    .select('name')
    .sort({ name: 1 });
};

module.exports = {
  listCollectionEntries: listCollectionInvoices,
  listMovements,
  listLedgerEntries,
  createMovement,
  updateMovement,
  deleteMovement,
  createLedgerEntry,
  updateLedgerEntry,
  deleteLedgerEntry,
  listEmployeesForPicker,
};
