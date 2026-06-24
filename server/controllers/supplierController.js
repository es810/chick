const Supplier = require('../models/Supplier');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { logAction } = require('../services/auditService');
const { deleteAllForSupplier } = require('../services/supplierStockService');

const getSuppliers = asyncHandler(async (req, res) => {
  const { search, page = 1, limit = 50 } = req.query;
  const query = {};

  if (search) {
    query.$or = [
      { name: { $regex: search, $options: 'i' } },
      { phone: { $regex: search, $options: 'i' } },
      { location: { $regex: search, $options: 'i' } },
    ];
  }

  const skip = (parseInt(page, 10) - 1) * parseInt(limit, 10);
  const [suppliers, total] = await Promise.all([
    Supplier.find(query).sort({ createdAt: -1 }).skip(skip).limit(parseInt(limit, 10)),
    Supplier.countDocuments(query),
  ]);

  res.json({
    success: true,
    data: suppliers,
    pagination: { total, page: parseInt(page, 10), pages: Math.ceil(total / limit) },
  });
});

const getSupplier = asyncHandler(async (req, res) => {
  const supplier = await Supplier.findById(req.params.id);
  if (!supplier) throw new ApiError(404, 'Supplier not found');
  res.json({ success: true, data: supplier });
});

const createSupplier = asyncHandler(async (req, res) => {
  const { name, location = '', phone } = req.body;
  const supplier = await Supplier.create({ name, location, phone });
  await logAction(req.user._id, req.user.name, 'CREATE_SUPPLIER', supplier.name);
  res.status(201).json({ success: true, data: supplier });
});

const updateSupplier = asyncHandler(async (req, res) => {
  const { name, location, phone } = req.body;
  const updates = {};
  if (name != null) updates.name = name;
  if (location != null) updates.location = location;
  if (phone != null) updates.phone = phone;

  const supplier = await Supplier.findByIdAndUpdate(req.params.id, updates, {
    new: true,
    runValidators: true,
  });
  if (!supplier) throw new ApiError(404, 'Supplier not found');
  await logAction(req.user._id, req.user.name, 'UPDATE_SUPPLIER', supplier.name);
  res.json({ success: true, data: supplier });
});

const deleteSupplier = asyncHandler(async (req, res) => {
  const supplier = await Supplier.findByIdAndDelete(req.params.id);
  if (!supplier) throw new ApiError(404, 'Supplier not found');
  await deleteAllForSupplier(supplier._id, req.user);
  await logAction(req.user._id, req.user.name, 'DELETE_SUPPLIER', supplier.name);
  res.json({ success: true, message: 'Supplier deleted' });
});

module.exports = { getSuppliers, getSupplier, createSupplier, updateSupplier, deleteSupplier };
