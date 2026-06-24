const express = require('express');
const { body } = require('express-validator');
const {
  getSuppliers,
  getSupplier,
  createSupplier,
  updateSupplier,
  deleteSupplier,
} = require('../controllers/supplierController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');
const supplierStockRoutes = require('./supplierStockRoutes');

const router = express.Router();

router.use(protect);

router.get('/', authorize('admin', 'employee'), getSuppliers);
router.use('/:supplierId/stock', supplierStockRoutes);
router.get('/:id', authorize('admin', 'employee'), getSupplier);

router.post(
  '/',
  authorize('admin'),
  [
    body('name').trim().notEmpty(),
    body('phone').trim().notEmpty(),
    body('location').optional().trim(),
  ],
  validate,
  createSupplier
);

router.put(
  '/:id',
  authorize('admin'),
  [
    body('name').optional().trim().notEmpty(),
    body('phone').optional().trim().notEmpty(),
    body('location').optional().trim(),
  ],
  validate,
  updateSupplier
);

router.delete('/:id', authorize('admin'), deleteSupplier);

module.exports = router;
