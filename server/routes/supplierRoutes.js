const express = require('express');
const { body } = require('express-validator');
const {
  getSuppliers,
  getSupplier,
  getSupplierAccountStatement,
  paySupplierDebt,
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
router.get('/:id/statement', authorize('admin', 'employee'), getSupplierAccountStatement);
router.get('/:id', authorize('admin', 'employee'), getSupplier);

router.post(
  '/:id/payments',
  authorize('admin', 'employee'),
  [
    body('paymentDate').isISO8601(),
    body('amount').isFloat({ min: 0.01 }),
    body('amountDeducted').optional().isFloat({ min: 0 }),
    body('notes').optional().trim(),
  ],
  validate,
  paySupplierDebt
);

router.post(
  '/',
  authorize('admin', 'employee'),
  [
    body('name').trim().notEmpty(),
    body('phone').trim().notEmpty(),
    body('location').optional().trim(),
    body('balance').optional().isFloat({ min: 0 }),
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
    body('balance').optional().isFloat({ min: 0 }),
  ],
  validate,
  updateSupplier
);

router.delete('/:id', authorize('admin'), deleteSupplier);

module.exports = router;
