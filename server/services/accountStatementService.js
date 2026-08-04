const Client = require('../models/Client');
const Supplier = require('../models/Supplier');
const Invoice = require('../models/Invoice');
const CollectionInvoice = require('../models/CollectionInvoice');
const SupplierStock = require('../models/SupplierStock');
const SupplierPayment = require('../models/SupplierPayment');
const EmployeeLedger = require('../models/EmployeeLedger');
const ApiError = require('../utils/apiError');

const lineTotal = (amount, pricePerKg, netWeight) => {
  if (amount > 0) return amount;
  return (pricePerKg || 0) * (netWeight || 0);
};

/**
 * Backfill supplier payments from older employee goods-debt rows that never
 * reduced supplier balance / appeared on the statement.
 */
const syncPaymentsFromEmployeeLedger = async (supplierId) => {
  const debts = await EmployeeLedger.find({
    type: 'debt',
    supplierId,
  }).populate('employeeId', 'name');

  for (const debt of debts) {
    const exists = await SupplierPayment.exists({ employeeLedgerId: debt._id });
    if (exists) continue;

    const supplier = await Supplier.findById(supplierId);
    if (!supplier) continue;

    const balanceBefore = supplier.balance || 0;
    const balanceAfter = Math.max(0, balanceBefore - debt.amount);
    supplier.balance = balanceAfter;
    await supplier.save();

    const employeeName = debt.employeeId?.name;
    const notes = [
      employeeName ? `عن طريق ${employeeName}` : null,
      debt.description || null,
    ]
      .filter(Boolean)
      .join(' — ');

    await SupplierPayment.create({
      supplierId,
      paymentDate: debt.createdAt || new Date(),
      amount: debt.amount,
      balanceBefore,
      balanceAfter,
      notes,
      employeeLedgerId: debt._id,
      employeeId: debt.employeeId?._id ?? debt.employeeId ?? null,
      createdBy: debt.createdBy,
    });
  }
};

const getClientStatement = async (clientId) => {
  const client = await Client.findById(clientId);
  if (!client) throw new ApiError(404, 'Client not found');

  const [invoices, collections] = await Promise.all([
    Invoice.find({ clientId })
      .populate('employeeId', 'name')
      .sort({ createdAt: 1 }),
    CollectionInvoice.find({ clientId })
      .populate('employeeId', 'name')
      .sort({ collectionDate: 1, createdAt: 1 }),
  ]);

  const entries = [];

  for (const invoice of invoices) {
    const affectsBalance = invoice.paymentStatus !== 'paid';
    entries.push({
      id: invoice._id.toString(),
      type: 'distribution',
      date: invoice.createdAt,
      description: `فاتورة توزيع #${invoice.invoiceNumber}`,
      subtitle: invoice.employeeId?.name ?? '',
      debit: affectsBalance ? invoice.totalPrice : 0,
      credit: 0,
      balanceAfter: invoice.balanceAfter ?? null,
      reference: invoice.invoiceNumber,
    });
  }

  for (const collection of collections) {
    const credit = collection.amountPaid + collection.amountDeducted;
    entries.push({
      id: collection._id.toString(),
      type: 'collection',
      date: collection.collectionDate,
      description: 'فاتورة تحصيل',
      subtitle: collection.employeeId?.name ?? '',
      debit: 0,
      credit,
      balanceAfter: collection.balanceAfter,
      reference: null,
    });
  }

  entries.sort((a, b) => new Date(a.date) - new Date(b.date));

  return {
    entity: {
      id: client._id.toString(),
      name: client.name,
      phone: client.phone,
      balance: client.balance,
    },
    entries,
  };
};

const getSupplierStatement = async (supplierId) => {
  await syncPaymentsFromEmployeeLedger(supplierId);

  const supplier = await Supplier.findById(supplierId);
  if (!supplier) throw new ApiError(404, 'Supplier not found');

  const stockItems = await SupplierStock.find({ supplierId }).sort({ updatedAt: 1 });
  const payments = await SupplierPayment.find({ supplierId })
    .populate('createdBy', 'name')
    .populate('employeeId', 'name')
    .sort({ paymentDate: 1, createdAt: 1 });

  const entries = [];

  for (const item of stockItems) {
    const total = lineTotal(item.totalAmount, item.pricePerKg, item.netWeight);
    entries.push({
      id: item._id.toString(),
      type: 'purchase',
      date: item.updatedAt,
      description: `بضاعة — ${item.chickenType}`,
      subtitle: item.location || '',
      debit: total,
      credit: 0,
      balanceAfter: null,
      reference: `${item.quantity}`,
    });
  }

  for (const payment of payments) {
    entries.push({
      id: payment._id.toString(),
      type: 'payment',
      date: payment.paymentDate,
      description: 'دفع دين',
      subtitle:
        payment.notes ||
        payment.employeeId?.name ||
        payment.createdBy?.name ||
        '',
      debit: 0,
      credit: payment.amount,
      balanceAfter: payment.balanceAfter,
      reference: null,
    });
  }

  entries.sort((a, b) => new Date(a.date) - new Date(b.date));

  const stockTotal = stockItems.reduce(
    (sum, item) => sum + lineTotal(item.totalAmount, item.pricePerKg, item.netWeight),
    0
  );
  const paidTotal = payments.reduce((sum, payment) => sum + payment.amount, 0);
  const ledgerDebt = Math.max(0, stockTotal - paidTotal);
  const currentBalance = supplier.balance || 0;

  // Sync upward only when stock purchases outpace stored balance AND there is no
  // payment history yet that would make a lower balance correct.
  if (ledgerDebt > currentBalance + 0.001 && paidTotal < 0.001) {
    supplier.balance = ledgerDebt;
    await supplier.save();
  }

  // If stored debt is higher than reconstructed stock−payments, show prior debt gap.
  const balanceGap = Math.max(0, (supplier.balance || 0) - ledgerDebt);
  if (balanceGap > 0.001) {
    entries.unshift({
      id: `${supplier._id.toString()}-prior-debt`,
      type: 'purchase',
      date: stockItems[0]?.createdAt || supplier.createdAt || new Date(),
      description: 'مديونية سابقة',
      subtitle: '',
      debit: balanceGap,
      credit: 0,
      balanceAfter: null,
      reference: null,
    });
  }

  let running = 0;
  for (const entry of entries) {
    running += entry.debit - entry.credit;
    if (entry.balanceAfter == null) {
      entry.balanceAfter = running;
    }
  }

  return {
    entity: {
      id: supplier._id.toString(),
      name: supplier.name,
      phone: supplier.phone,
      balance: supplier.balance,
    },
    entries,
  };
};

module.exports = { getClientStatement, getSupplierStatement };
