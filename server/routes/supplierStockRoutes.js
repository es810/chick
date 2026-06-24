const express = require('express');
const { body } = require('express-validator');
const {
  getSupplierStock,
  createSupplierStock,
  updateSupplierStock,
  deleteSupplierStockItem,
} = require('../controllers/supplierStockController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router({ mergeParams: true });

router.use(protect);

router.get('/', authorize('admin', 'employee'), getSupplierStock);

router.post(
  '/',
  authorize('admin'),
  [
    body('chickenType').trim().notEmpty(),
    body('quantity').isInt({ min: 1 }),
    body('location').optional().isString(),
    body('grossWeight').optional().isFloat({ min: 0 }),
    body('tareWeight').optional().isFloat({ min: 0 }),
    body('netWeight').optional().isFloat({ min: 0 }),
    body('totalAmount').optional().isFloat({ min: 0 }),
    body('averageWeight').optional().isFloat({ min: 0 }),
    body('pricePerKg').optional().isFloat({ min: 0 }),
  ],
  validate,
  createSupplierStock
);

router.put('/:id', authorize('admin'), updateSupplierStock);
router.delete('/:id', authorize('admin'), deleteSupplierStockItem);

module.exports = router;
