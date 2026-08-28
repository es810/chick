const SupplierStock = require('../models/SupplierStock');
const asyncHandler = require('../utils/asyncHandler');
const {
  addSupplierStock,
  updateSupplierStock,
  deleteSupplierStock,
  ensureSupplier,
} = require('../services/supplierStockService');

const getSupplierStock = asyncHandler(async (req, res) => {
  await ensureSupplier(req.params.supplierId);
  const stocks = await SupplierStock.find({ supplierId: req.params.supplierId }).sort({
    createdAt: -1,
  });
  res.json({ success: true, data: stocks });
});

const createSupplierStock = asyncHandler(async (req, res) => {
  const stock = await addSupplierStock(req.params.supplierId, req.body, req.user);
  res.status(201).json({ success: true, data: stock });
});

const updateSupplierStockHandler = asyncHandler(async (req, res) => {
  const stock = await updateSupplierStock(
    req.params.supplierId,
    req.params.id,
    req.body,
    req.user
  );
  res.json({ success: true, data: stock });
});

const deleteSupplierStockItem = asyncHandler(async (req, res) => {
  await deleteSupplierStock(req.params.supplierId, req.params.id, req.user);
  res.json({ success: true, message: 'Supplier stock deleted' });
});

module.exports = {
  getSupplierStock,
  createSupplierStock,
  updateSupplierStock: updateSupplierStockHandler,
  deleteSupplierStockItem,
};
