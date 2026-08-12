const mongoose = require('mongoose');
const User = require('../models/User');
const Supplier = require('../models/Supplier');
const EmployeeLedger = require('../models/EmployeeLedger');
const SupplierPayment = require('../models/SupplierPayment');
const { getTreasurySummary } = require('./treasuryService');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');

const getEmployeeLedger = async (employeeId) => {
  const employee = await User.findOne({ _id: employeeId, role: 'employee' });
  if (!employee) throw new ApiError(404, 'Employee not found');

  const [entries, totals] = await Promise.all([
    EmployeeLedger.find({ employeeId })
      .populate('createdBy', 'name')
      .populate('supplierId', 'name')
      .sort({ createdAt: -1 })
      .limit(100),
    EmployeeLedger.aggregate([
      { $match: { employeeId: new mongoose.Types.ObjectId(employeeId) } },
      {
        $group: {
          _id: '$type',
          total: { $sum: '$amount' },
          count: { $sum: 1 },
        },
      },
    ]),
  ]);

  let totalExpenses = 0;
  let totalDebt = 0;
  for (const row of totals) {
    if (row._id === 'expense') totalExpenses = row.total;
    if (row._id === 'debt') totalDebt = row.total;
  }

  return { employee, entries, totalExpenses, totalDebt };
};

/**
 * Apply employee goods-debt as a supplier payment (reduces supplier AP).
 * Treasury impact stays on the ledger debt row (التحميل); not double-withdrawn.
 */
const applySupplierPaymentFromLedger = async (session, {
  supplier,
  amount,
  employee,
  ledgerEntryId,
  description,
  user,
  paymentDate = new Date(),
}) => {
  const balanceBefore = supplier.balance || 0;
  const balanceAfter = Math.max(0, balanceBefore - amount);

  supplier.balance = balanceAfter;
  await supplier.save({ session });

  const notes = [
    employee?.name ? `عن طريق ${employee.name}` : null,
    description || null,
  ]
    .filter(Boolean)
    .join(' — ');

  const [payment] = await SupplierPayment.create(
    [
      {
        supplierId: supplier._id,
        paymentDate,
        amount,
        balanceBefore,
        balanceAfter,
        notes,
        employeeLedgerId: ledgerEntryId,
        employeeId: employee?._id ?? null,
        createdBy: user._id,
      },
    ],
    { session }
  );

  return payment;
};

const reverseSupplierPaymentFromLedger = async (session, ledgerEntryId) => {
  const payment = await SupplierPayment.findOne({ employeeLedgerId: ledgerEntryId }).session(
    session
  );
  if (!payment) return null;

  const supplier = await Supplier.findById(payment.supplierId).session(session);
  if (supplier) {
    supplier.balance =
      (supplier.balance || 0) + payment.amount + (payment.amountDeducted || 0);
    await supplier.save({ session });
  }

  await SupplierPayment.deleteOne({ _id: payment._id }).session(session);
  return payment;
};

const addLedgerEntry = async (employeeId, type, amount, description, user, supplierId = null) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const employee = await User.findOne({ _id: employeeId, role: 'employee' }).session(session);
    if (!employee) throw new ApiError(404, 'Employee not found');

    let supplier = null;
    if (type === 'debt') {
      if (!supplierId) throw new ApiError(400, 'Supplier is required for goods debt');
      supplier = await Supplier.findById(supplierId).session(session);
      if (!supplier) throw new ApiError(404, 'Supplier not found');
      if (amount > (supplier.balance || 0)) {
        throw new ApiError(400, 'Payment amount cannot exceed supplier debt');
      }
    }

    const summary = await getTreasurySummary();
    if (summary.balance < amount) {
      throw new ApiError(400, 'Insufficient main treasury balance');
    }

    const [entry] = await EmployeeLedger.create(
      [
        {
          employeeId,
          type,
          amount,
          description,
          supplierId: supplier?._id ?? null,
          createdBy: user._id,
        },
      ],
      { session }
    );

    if (type === 'debt' && supplier) {
      await applySupplierPaymentFromLedger(session, {
        supplier,
        amount,
        employee,
        ledgerEntryId: entry._id,
        description,
        user,
      });
    }

    await session.commitTransaction();

    const action = type === 'expense' ? 'ADD_EMPLOYEE_EXPENSE' : 'ADD_EMPLOYEE_DEBT';
    await logAction(user._id, user.name, action, employee.name, {
      amount,
      description,
      supplierId: supplier?._id?.toString(),
      supplierName: supplier?.name,
    });

    return EmployeeLedger.findById(entry._id)
      .populate('createdBy', 'name')
      .populate('supplierId', 'name');
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

module.exports = {
  getEmployeeLedger,
  addLedgerEntry,
  applySupplierPaymentFromLedger,
  reverseSupplierPaymentFromLedger,
};
