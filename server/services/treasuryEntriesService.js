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
    subtitle: [e.supplierId?.name, e.employeeId?.name].filter(Boolean).join(' — '),
    createdAt: e.createdAt,
    supplierId: e.supplierId?._id?.toString() ?? e.supplierId?.toString() ?? null,
    supplierName: e.supplierId?.name ?? null,
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

const createLedgerEntry = async (
  type,
  employeeId,
  amount,
  description,
  user,
  supplierId = null,
  amountDeducted = 0
) => {
  const ledgerType = type === 'loading' ? 'debt' : 'expense';
  const entry = await addLedgerEntry(
    employeeId,
    ledgerType,
    amount,
    description,
    user,
    supplierId,
    amountDeducted
  );
  await entry.populate('employeeId', 'name');
  await entry.populate('createdBy', 'name');
  await entry.populate('supplierId', 'name');

  return {
    id: entry._id,
    category: type,
    amount: entry.amount,
    description: entry.description,
    subtitle: [entry.supplierId?.name, entry.employeeId?.name].filter(Boolean).join(' — '),
    createdAt: entry.createdAt,
    supplierId: entry.supplierId?._id?.toString() ?? null,
    supplierName: entry.supplierId?.name ?? null,
  };
};

const updateLedgerEntry = async (id, { amount, description }) => {
  const mongoose = require('mongoose');
  const Supplier = require('../models/Supplier');
  const SupplierPayment = require('../models/SupplierPayment');
  const { reverseSupplierPaymentFromLedger, applySupplierPaymentFromLedger } = require('./employeeLedgerService');

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const entry = await EmployeeLedger.findById(id).session(session);
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
    await entry.save({ session });

    if (entry.type === 'debt' && entry.supplierId) {
      const previousPayment = await SupplierPayment.findOne({
        employeeLedgerId: entry._id,
      }).session(session);
      const previousDeducted = previousPayment?.amountDeducted || 0;

      await reverseSupplierPaymentFromLedger(session, entry._id);
      const supplier = await Supplier.findById(entry.supplierId).session(session);
      const employee = await User.findById(entry.employeeId).session(session);
      if (!supplier) throw new ApiError(404, 'Supplier not found');
      if (entry.amount + previousDeducted > (supplier.balance || 0)) {
        throw new ApiError(400, 'Payment and discount cannot exceed supplier debt');
      }
      await applySupplierPaymentFromLedger(session, {
        supplier,
        amount: entry.amount,
        amountDeducted: previousDeducted,
        employee,
        ledgerEntryId: entry._id,
        description: entry.description,
        user: { _id: entry.createdBy },
        paymentDate: entry.createdAt,
      });
    }

    await session.commitTransaction();
    return entry;
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

const deleteLedgerEntry = async (id) => {
  const mongoose = require('mongoose');
  const { reverseSupplierPaymentFromLedger } = require('./employeeLedgerService');

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const entry = await EmployeeLedger.findById(id).session(session);
    if (!entry) throw new ApiError(404, 'Entry not found');

    if (entry.type === 'debt' && entry.supplierId) {
      await reverseSupplierPaymentFromLedger(session, entry._id);
    }

    await EmployeeLedger.deleteOne({ _id: entry._id }).session(session);
    await session.commitTransaction();
    return entry;
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
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
