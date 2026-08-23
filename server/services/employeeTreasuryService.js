const mongoose = require('mongoose');
const User = require('../models/User');
const CollectionInvoice = require('../models/CollectionInvoice');
const EmployeeTreasuryTransfer = require('../models/EmployeeTreasuryTransfer');
const EmployeeLedger = require('../models/EmployeeLedger');
const SalaryAdvance = require('../models/SalaryAdvance');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');

const toBalanceMap = (rows) =>
  Object.fromEntries(rows.map((row) => [row._id.toString(), row.total]));

const sumFor = (map, id) => map[id] ?? 0;

const buildTreasuryTotalsMap = async (employeeIds) => {
  if (!employeeIds.length) return {};

  const ids = employeeIds.map((id) =>
    id instanceof mongoose.Types.ObjectId ? id : new mongoose.Types.ObjectId(id)
  );

  const [collections, incoming, outgoing, expenses, debts, advances] = await Promise.all([
    CollectionInvoice.aggregate([
      { $match: { employeeId: { $in: ids } } },
      { $group: { _id: '$employeeId', total: { $sum: '$amountPaid' } } },
    ]),
    EmployeeTreasuryTransfer.aggregate([
      { $match: { toEmployeeId: { $in: ids } } },
      { $group: { _id: '$toEmployeeId', total: { $sum: '$amount' } } },
    ]),
    EmployeeTreasuryTransfer.aggregate([
      { $match: { fromEmployeeId: { $in: ids } } },
      { $group: { _id: '$fromEmployeeId', total: { $sum: '$amount' } } },
    ]),
    EmployeeLedger.aggregate([
      { $match: { employeeId: { $in: ids }, type: 'expense' } },
      { $group: { _id: '$employeeId', total: { $sum: '$amount' } } },
    ]),
    EmployeeLedger.aggregate([
      { $match: { employeeId: { $in: ids }, type: 'debt' } },
      { $group: { _id: '$employeeId', total: { $sum: '$amount' } } },
    ]),
    SalaryAdvance.aggregate([
      { $match: { employeeId: { $in: ids } } },
      { $group: { _id: '$employeeId', total: { $sum: '$amount' } } },
    ]),
  ]);

  const collectionsMap = toBalanceMap(collections);
  const incomingMap = toBalanceMap(incoming);
  const outgoingMap = toBalanceMap(outgoing);
  const expensesMap = toBalanceMap(expenses);
  const debtsMap = toBalanceMap(debts);
  const advancesMap = toBalanceMap(advances);

  const totals = {};
  for (const id of ids) {
    const key = id.toString();
    const collection = sumFor(collectionsMap, key);
    const incomingTransfer = sumFor(incomingMap, key);
    const outgoingTransfer = sumFor(outgoingMap, key);
    const expenseTotal = sumFor(expensesMap, key);
    const debtTotal = sumFor(debtsMap, key);
    const advanceTotal = sumFor(advancesMap, key);
  const balance =
      collection +
      incomingTransfer -
      expenseTotal -
      advanceTotal -
      debtTotal -
      outgoingTransfer;

    totals[key] = {
      balance,
      collection,
      incomingTransfer,
      expenses: expenseTotal,
      advances: advanceTotal,
      debts: debtTotal,
      outgoingTransfer,
    };
  }

  return totals;
};

const getEmployeeTreasurySummary = async (employeeId) => {
  const employee = await User.findOne({ _id: employeeId, role: 'employee' });
  if (!employee) throw new ApiError(404, 'Employee not found');

  const totalsMap = await buildTreasuryTotalsMap([employee._id]);
  const totals = totalsMap[employee._id.toString()] ?? {
    balance: 0,
    collection: 0,
    incomingTransfer: 0,
    expenses: 0,
    advances: 0,
    debts: 0,
    outgoingTransfer: 0,
  };

  return {
    employee: {
      id: employee._id.toString(),
      name: employee.name,
      phone: employee.phone,
    },
    ...totals,
  };
};

const getEmployeeTreasuryBalance = async (employeeId) => {
  const summary = await getEmployeeTreasurySummary(employeeId);
  return summary.balance;
};

const attachTreasuryBalances = async (employees) => {
  if (!employees.length) return [];

  const totalsMap = await buildTreasuryTotalsMap(employees.map((employee) => employee._id));

  return employees.map((employee) => {
    const id = employee._id.toString();
    const totals = totalsMap[id] ?? { balance: 0 };
    const plain = typeof employee.toObject === 'function' ? employee.toObject() : employee;
    return { ...plain, treasuryBalance: totals.balance };
  });
};

const getEmployeeTreasuryStatement = async (employeeId) => {
  const summary = await getEmployeeTreasurySummary(employeeId);
  const empId = new mongoose.Types.ObjectId(employeeId);

  const [collections, incomingTransfers, outgoingTransfers, ledgerEntries, advances] =
    await Promise.all([
      CollectionInvoice.find({ employeeId: empId })
        .populate('clientId', 'name')
        .sort({ collectionDate: 1, createdAt: 1 }),
      EmployeeTreasuryTransfer.find({ toEmployeeId: empId })
        .populate('fromEmployeeId', 'name')
        .sort({ createdAt: 1 }),
      EmployeeTreasuryTransfer.find({ fromEmployeeId: empId })
        .populate('toEmployeeId', 'name')
        .sort({ createdAt: 1 }),
      EmployeeLedger.find({ employeeId: empId })
        .populate('supplierId', 'name')
        .sort({ createdAt: 1 }),
      SalaryAdvance.find({ employeeId: empId }).sort({ advanceDate: 1, createdAt: 1 }),
    ]);

  const entries = [];

  for (const invoice of collections) {
    entries.push({
      id: invoice._id.toString(),
      type: 'collection',
      date: invoice.collectionDate,
      description: 'فاتورة تحصيل',
      subtitle: invoice.clientId?.name ?? '',
      debit: 0,
      credit: invoice.amountPaid,
      balanceAfter: null,
      reference: null,
    });
  }

  for (const transfer of incomingTransfers) {
    entries.push({
      id: transfer._id.toString(),
      type: 'transfer_in',
      date: transfer.createdAt,
      description: 'تحويل وارد',
      subtitle: transfer.fromEmployeeId?.name ?? transfer.notes,
      debit: 0,
      credit: transfer.amount,
      balanceAfter: null,
      reference: null,
    });
  }

  for (const transfer of outgoingTransfers) {
    entries.push({
      id: transfer._id.toString(),
      type: 'transfer_out',
      date: transfer.createdAt,
      description: 'تحويل صادر',
      subtitle: transfer.toEmployeeId?.name ?? transfer.notes,
      debit: transfer.amount,
      credit: 0,
      balanceAfter: null,
      reference: null,
    });
  }

  for (const entry of ledgerEntries) {
    if (entry.type === 'expense') {
      entries.push({
        id: entry._id.toString(),
        type: 'expense',
        date: entry.createdAt,
        description: 'مصروف',
        subtitle: entry.description,
        debit: entry.amount,
        credit: 0,
        balanceAfter: null,
        reference: null,
      });
    } else if (entry.type === 'debt') {
      entries.push({
        id: entry._id.toString(),
        type: 'debt',
        date: entry.createdAt,
        description: 'مديونية بضاعة',
        subtitle: entry.supplierId?.name
          ? `${entry.supplierId.name} — ${entry.description}`
          : entry.description,
        debit: entry.amount,
        credit: 0,
        balanceAfter: null,
        reference: null,
      });
    }
  }

  for (const advance of advances) {
    entries.push({
      id: advance._id.toString(),
      type: 'advance',
      date: advance.advanceDate,
      description: 'سلفة',
      subtitle: advance.notes || '',
      debit: advance.amount,
      credit: 0,
      balanceAfter: null,
      reference: null,
    });
  }

  entries.sort((a, b) => new Date(a.date) - new Date(b.date));

  let running = 0;
  for (const entry of entries) {
    running += entry.credit - entry.debit;
    entry.balanceAfter = running;
  }

  return {
    entity: {
      id: summary.employee.id,
      name: summary.employee.name,
      phone: summary.employee.phone,
      balance: summary.balance,
    },
    entries,
    totals: {
      collection: summary.collection,
      incomingTransfer: summary.incomingTransfer,
      expenses: summary.expenses,
      advances: summary.advances,
      debts: summary.debts,
      outgoingTransfer: summary.outgoingTransfer,
    },
  };
};

const transferEmployeeTreasury = async (
  { fromEmployeeId, toEmployeeId, amount, notes },
  user
) => {
  const fromId = String(fromEmployeeId);
  const toId = String(toEmployeeId);
  const transferAmount = Number(amount);

  if (!Number.isFinite(transferAmount) || transferAmount <= 0) {
    throw new ApiError(400, 'Amount must be greater than 0');
  }
  if (fromId === toId) {
    throw new ApiError(400, 'Cannot transfer to the same employee');
  }

  const [fromEmployee, toEmployee] = await Promise.all([
    User.findOne({ _id: fromId, role: 'employee', isActive: { $ne: false } }),
    User.findOne({ _id: toId, role: 'employee', isActive: { $ne: false } }),
  ]);

  if (!fromEmployee) throw new ApiError(404, 'Source employee not found');
  if (!toEmployee) throw new ApiError(404, 'Destination employee not found');

  const balance = await getEmployeeTreasuryBalance(fromId);
  if (balance < transferAmount) {
    throw new ApiError(400, 'Insufficient employee treasury balance');
  }

  // Single insert — no Mongo transaction (avoids abort/conflict errors on Atlas).
  const transfer = await EmployeeTreasuryTransfer.create({
    fromEmployeeId: fromId,
    toEmployeeId: toId,
    amount: transferAmount,
    notes: notes || '',
    createdBy: user._id,
  });

  await logAction(user._id, user.name, 'EMPLOYEE_TREASURY_TRANSFER', fromEmployee.name, {
    toEmployee: toEmployee.name,
    amount: transferAmount,
    notes: notes || '',
  });

  return EmployeeTreasuryTransfer.findById(transfer._id)
    .populate('fromEmployeeId', 'name')
    .populate('toEmployeeId', 'name')
    .populate('createdBy', 'name');
};

module.exports = {
  getEmployeeTreasuryBalance,
  getEmployeeTreasurySummary,
  getEmployeeTreasuryStatement,
  attachTreasuryBalances,
  transferEmployeeTreasury,
};
