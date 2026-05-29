const asyncHandler = require('../utils/asyncHandler');
const {
  getMainTreasury,
  getTreasurySummary,
  updateMainTreasury,
  addExternalRevenue,
  withdrawFromTreasury,
  resetMainTreasury,
} = require('../services/treasuryService');
const { deleteInvoice } = require('../services/invoiceService');
const {
  listCollectionEntries,
  listMovements,
  listLedgerEntries,
  createMovement,
  updateMovement,
  deleteMovement,
  createLedgerEntry,
  updateLedgerEntry,
  deleteLedgerEntry,
  listEmployeesForPicker,
} = require('../services/treasuryEntriesService');

const getMainTreasuryHandler = asyncHandler(async (req, res) => {
  const treasury = await getMainTreasury();
  res.json({ success: true, data: treasury });
});

const getTreasurySummaryHandler = asyncHandler(async (req, res) => {
  const summary = await getTreasurySummary();
  res.json({ success: true, data: summary });
});

const updateMainTreasuryHandler = asyncHandler(async (req, res) => {
  const openingBalance = req.body.openingBalance ?? req.body.balance;
  const treasury = await updateMainTreasury(openingBalance, req.user);
  const summary = await getTreasurySummary();
  res.json({ success: true, data: summary });
});

const addExternalRevenueHandler = asyncHandler(async (req, res) => {
  const { amount, description } = req.body;
  const summary = await addExternalRevenue(amount, description, req.user);
  res.json({ success: true, data: summary });
});

const withdrawFromTreasuryHandler = asyncHandler(async (req, res) => {
  const { amount, description } = req.body;
  const summary = await withdrawFromTreasury(amount, description, req.user);
  res.json({ success: true, data: summary });
});

const resetMainTreasuryHandler = asyncHandler(async (req, res) => {
  const summary = await resetMainTreasury(req.user);
  res.json({ success: true, data: summary });
});

const listTreasuryEntriesHandler = asyncHandler(async (req, res) => {
  const { category } = req.query;
  let data;
  switch (category) {
    case 'collection':
      data = await listCollectionEntries();
      break;
    case 'external_revenue':
      data = await listMovements('external_revenue');
      break;
    case 'withdrawal':
      data = await listMovements('withdrawal');
      break;
    case 'loading':
      data = await listLedgerEntries('debt');
      break;
    case 'expense':
      data = await listLedgerEntries('expense');
      break;
    default:
      return res.status(400).json({ success: false, message: 'Invalid category' });
  }
  res.json({ success: true, data });
});

const createTreasuryEntryHandler = asyncHandler(async (req, res) => {
  const { category, amount, description, employeeId } = req.body;
  let entry;

  if (category === 'external_revenue' || category === 'withdrawal') {
    entry = await createMovement(category, amount, description, req.user);
  } else if (category === 'loading' || category === 'expense') {
    if (!employeeId) {
      return res.status(400).json({ success: false, message: 'employeeId is required' });
    }
    entry = await createLedgerEntry(category, employeeId, amount, description, req.user);
  } else {
    return res.status(400).json({ success: false, message: 'Use invoice screen to add collection' });
  }

  const summary = await getTreasurySummary();
  res.status(201).json({ success: true, data: { entry, summary } });
});

const updateTreasuryEntryHandler = asyncHandler(async (req, res) => {
  const { category } = req.query;
  const { amount, description } = req.body;

  if (category === 'collection') {
    return res.status(400).json({ success: false, message: 'Edit invoice from invoice screen' });
  }
  if (category === 'external_revenue' || category === 'withdrawal') {
    await updateMovement(req.params.id, { amount, description });
  } else if (category === 'loading' || category === 'expense') {
    await updateLedgerEntry(req.params.id, { amount, description });
  } else {
    return res.status(400).json({ success: false, message: 'Invalid category' });
  }

  const summary = await getTreasurySummary();
  res.json({ success: true, data: summary });
});

const deleteTreasuryEntryHandler = asyncHandler(async (req, res) => {
  const { category } = req.query;

  if (category === 'collection') {
    await deleteInvoice(req.params.id, req.user);
  } else if (category === 'external_revenue' || category === 'withdrawal') {
    await deleteMovement(req.params.id);
  } else if (category === 'loading' || category === 'expense') {
    await deleteLedgerEntry(req.params.id);
  } else {
    return res.status(400).json({ success: false, message: 'Invalid category' });
  }

  const summary = await getTreasurySummary();
  res.json({ success: true, data: summary });
});

const listTreasuryEmployeesHandler = asyncHandler(async (req, res) => {
  const employees = await listEmployeesForPicker();
  res.json({ success: true, data: employees });
});

module.exports = {
  getMainTreasuryHandler,
  getTreasurySummaryHandler,
  updateMainTreasuryHandler,
  addExternalRevenueHandler,
  withdrawFromTreasuryHandler,
  resetMainTreasuryHandler,
  listTreasuryEntriesHandler,
  createTreasuryEntryHandler,
  updateTreasuryEntryHandler,
  deleteTreasuryEntryHandler,
  listTreasuryEmployeesHandler,
};
