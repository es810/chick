const Client = require('../models/Client');
const User = require('../models/User');
const TreasuryMovement = require('../models/TreasuryMovement');
const CollectionInvoice = require('../models/CollectionInvoice');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');
const { normalizeToCairoDayStart } = require('../utils/businessCalendar');

const toEntry = (doc) => ({
  id: doc._id,
  category: 'collection',
  amount: doc.amountPaid,
  description: doc.clientId?.name ?? '',
  subtitle: doc.employeeId?.name ?? '',
  clientId: doc.clientId?._id?.toString() ?? doc.clientId?.toString(),
  clientName: doc.clientId?.name ?? '',
  employeeId: doc.employeeId?._id?.toString() ?? doc.employeeId?.toString(),
  employeeName: doc.employeeId?.name ?? '',
  collectionDate: doc.collectionDate,
  amountPaid: doc.amountPaid,
  amountDeducted: doc.amountDeducted,
  balanceBefore: doc.balanceBefore,
  balanceAfter: doc.balanceAfter,
  createdAt: doc.createdAt,
});

const listCollectionInvoices = async () => {
  const invoices = await CollectionInvoice.find()
    .populate('clientId', 'name')
    .populate('employeeId', 'name')
    .sort({ collectionDate: -1, createdAt: -1 })
    .limit(500);

  return invoices.map(toEntry);
};

const getCollectionInvoice = async (id) => {
  const invoice = await CollectionInvoice.findById(id)
    .populate('clientId', 'name phone')
    .populate('employeeId', 'name');
  if (!invoice) throw new ApiError(404, 'Collection invoice not found');
  return toEntry(invoice);
};

const validateAmounts = ({ amountPaid, amountDeducted, balanceBefore }) => {
  if (amountPaid <= 0) {
    throw new ApiError(400, 'Amount paid must be greater than zero');
  }
  if (amountDeducted < 0) {
    throw new ApiError(400, 'Deducted amount cannot be negative');
  }
  if (amountPaid + amountDeducted > balanceBefore) {
    throw new ApiError(400, 'Payment and discount cannot exceed balance before payment');
  }
  return Math.max(0, balanceBefore - amountPaid - amountDeducted);
};

const createCollectionInvoice = async (data, user) => {
  const {
    clientId,
    employeeId,
    collectionDate,
    amountPaid,
    amountDeducted,
  } = data;

  const client = await Client.findById(clientId);
  if (!client) throw new ApiError(404, 'Client not found');

  const employee = await User.findOne({ _id: employeeId, role: 'employee' });
  if (!employee) throw new ApiError(404, 'Employee not found');

  const balanceBefore = client.balance;
  const balanceAfter = validateAmounts({
    amountPaid,
    amountDeducted,
    balanceBefore,
  });

  const movement = await TreasuryMovement.create({
    type: 'collection',
    amount: amountPaid,
    description: `تحصيل - ${client.name}`,
    createdBy: user._id,
  });

  const invoice = await CollectionInvoice.create({
    clientId,
    employeeId,
    collectionDate: normalizeToCairoDayStart(collectionDate),
    amountPaid,
    amountDeducted,
    balanceBefore,
    balanceAfter,
    treasuryMovementId: movement._id,
    createdBy: user._id,
  });

  client.balance = balanceAfter;
  await client.save();

  await logAction(user._id, user.name, 'CREATE_COLLECTION_INVOICE', client.name, {
    amountPaid,
    amountDeducted,
  });

  await invoice.populate('clientId', 'name');
  await invoice.populate('employeeId', 'name');
  return toEntry(invoice);
};

const updateCollectionInvoice = async (id, data, user) => {
  const invoice = await CollectionInvoice.findById(id);
  if (!invoice) throw new ApiError(404, 'Collection invoice not found');

  const oldClient = await Client.findById(invoice.clientId);
  if (oldClient) {
    oldClient.balance += invoice.amountPaid + invoice.amountDeducted;
    await oldClient.save();
  }

  const {
    clientId,
    employeeId,
    collectionDate,
    amountPaid,
    amountDeducted,
  } = data;

  const client = await Client.findById(clientId);
  if (!client) throw new ApiError(404, 'Client not found');

  const employee = await User.findOne({ _id: employeeId, role: 'employee' });
  if (!employee) throw new ApiError(404, 'Employee not found');

  const balanceBefore = client.balance;
  const balanceAfter = validateAmounts({
    amountPaid,
    amountDeducted,
    balanceBefore,
  });

  const movement = await TreasuryMovement.findById(invoice.treasuryMovementId);
  if (movement) {
    movement.amount = amountPaid;
    movement.description = `تحصيل - ${client.name}`;
    await movement.save();
  }

  invoice.clientId = client._id;
  invoice.employeeId = employeeId;
  invoice.collectionDate = normalizeToCairoDayStart(collectionDate);
  invoice.amountPaid = amountPaid;
  invoice.amountDeducted = amountDeducted;
  invoice.balanceBefore = balanceBefore;
  invoice.balanceAfter = balanceAfter;
  await invoice.save();

  client.balance = balanceAfter;
  await client.save();

  await logAction(user._id, user.name, 'UPDATE_COLLECTION_INVOICE', client.name, {
    amountPaid,
    amountDeducted,
  });

  await invoice.populate('clientId', 'name');
  await invoice.populate('employeeId', 'name');
  return toEntry(invoice);
};

const deleteCollectionInvoice = async (id, user) => {
  const invoice = await CollectionInvoice.findById(id);
  if (!invoice) throw new ApiError(404, 'Collection invoice not found');

  const client = await Client.findById(invoice.clientId);
  if (client) {
    client.balance += invoice.amountPaid + invoice.amountDeducted;
    await client.save();
  }

  await TreasuryMovement.findByIdAndDelete(invoice.treasuryMovementId);
  await CollectionInvoice.findByIdAndDelete(id);

  await logAction(user._id, user.name, 'DELETE_COLLECTION_INVOICE', client?.name ?? id, {
    amountPaid: invoice.amountPaid,
  });
};

module.exports = {
  listCollectionInvoices,
  getCollectionInvoice,
  createCollectionInvoice,
  updateCollectionInvoice,
  deleteCollectionInvoice,
};
