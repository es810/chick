const asyncHandler = require('../utils/asyncHandler');
const {
  listCollectionInvoices,
  createCollectionInvoice,
  updateCollectionInvoice,
  deleteCollectionInvoice,
} = require('../services/collectionInvoiceService');
const { listEmployeesForPicker } = require('../services/treasuryEntriesService');
const { getTreasurySummary } = require('../services/treasuryService');

const listCollectionInvoicesHandler = asyncHandler(async (req, res) => {
  const data = await listCollectionInvoices();
  res.json({ success: true, data });
});

const listCollectionEmployeesHandler = asyncHandler(async (req, res) => {
  const employees = await listEmployeesForPicker();
  res.json({ success: true, data: employees });
});

const createCollectionInvoiceHandler = asyncHandler(async (req, res) => {
  const entry = await createCollectionInvoice(req.body, req.user);
  const summary = await getTreasurySummary();
  res.status(201).json({ success: true, data: { entry, summary } });
});

const updateCollectionInvoiceHandler = asyncHandler(async (req, res) => {
  const entry = await updateCollectionInvoice(req.params.id, req.body, req.user);
  const summary = await getTreasurySummary();
  res.json({ success: true, data: { entry, summary } });
});

const deleteCollectionInvoiceHandler = asyncHandler(async (req, res) => {
  await deleteCollectionInvoice(req.params.id, req.user);
  const summary = await getTreasurySummary();
  res.json({ success: true, data: summary });
});

module.exports = {
  listCollectionInvoicesHandler,
  listCollectionEmployeesHandler,
  createCollectionInvoiceHandler,
  updateCollectionInvoiceHandler,
  deleteCollectionInvoiceHandler,
};
