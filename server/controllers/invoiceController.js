const Invoice = require('../models/Invoice');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const {
  createInvoice,
  updateInvoiceFull,
  updatePaymentStatus,
  deleteInvoice,
} = require('../services/invoiceService');

const getInvoices = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, paymentStatus, clientId, search } = req.query;
  const query = {};

  if (req.user.role === 'client' && req.user.clientProfile) {
    query.clientId = req.user.clientProfile;
  } else if (req.user.role === 'employee') {
    query.employeeId = req.user._id;
  }

  if (paymentStatus) query.paymentStatus = paymentStatus;
  if (clientId) query.clientId = clientId;

  const skip = (parseInt(page) - 1) * parseInt(limit);
  let invoicesQuery = Invoice.find(query)
    .populate('clientId', 'name phone address')
    .populate('employeeId', 'name')
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(parseInt(limit));

  if (search) {
    invoicesQuery = Invoice.find({
      ...query,
      invoiceNumber: { $regex: search, $options: 'i' },
    })
      .populate('clientId', 'name phone')
      .populate('employeeId', 'name')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));
  }

  const [invoices, total] = await Promise.all([
    invoicesQuery,
    Invoice.countDocuments(query),
  ]);

  res.json({
    success: true,
    data: invoices,
    pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) },
  });
});

const getInvoice = asyncHandler(async (req, res) => {
  const invoice = await Invoice.findById(req.params.id)
    .populate('clientId', 'name phone address balance')
    .populate('employeeId', 'name phone email');

  if (!invoice) throw new ApiError(404, 'Invoice not found');

  if (req.user.role === 'client' && req.user.clientProfile?.toString() !== invoice.clientId._id.toString()) {
    throw new ApiError(403, 'Not authorized to view this invoice');
  }

  res.json({ success: true, data: invoice });
});

const createInvoiceHandler = asyncHandler(async (req, res) => {
  const invoice = await createInvoice(req.body, req.user);
  res.status(201).json({ success: true, data: invoice });
});

const updateInvoice = asyncHandler(async (req, res) => {
  const { paymentStatus, items, clientId, notes } = req.body;

  if (items?.length) {
    if (req.user.role !== 'admin') {
      throw new ApiError(403, 'Only admin can edit invoice details');
    }
    const updated = await updateInvoiceFull(req.params.id, req.body, req.user);
    return res.json({ success: true, data: updated });
  }

  const invoice = await Invoice.findById(req.params.id);
  if (!invoice) throw new ApiError(404, 'Invoice not found');

  if (paymentStatus) {
    const updated = await updatePaymentStatus(req.params.id, paymentStatus, req.user);
    return res.json({ success: true, data: updated });
  }

  if (notes !== undefined && req.user.role === 'admin') {
    invoice.notes = notes;
    await invoice.save();
  }

  res.json({ success: true, data: invoice });
});

const deleteInvoiceHandler = asyncHandler(async (req, res) => {
  const result = await deleteInvoice(req.params.id, req.user);
  res.json({ success: true, data: result });
});

module.exports = {
  getInvoices,
  getInvoice,
  createInvoiceHandler,
  updateInvoice,
  deleteInvoiceHandler,
};
