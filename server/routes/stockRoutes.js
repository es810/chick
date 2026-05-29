const express = require('express');
const { body } = require('express-validator');
const {
  getStock,
  createStock,
  updateStock,
  deleteStock,
  getStockMovements,
  getAlerts,
} = require('../controllers/stockController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.use(protect);

router.get('/', authorize('admin', 'employee'), getStock);
router.get('/alerts', authorize('admin', 'employee'), getAlerts);
router.get('/movements', authorize('admin'), getStockMovements);

router.post(
  '/',
  authorize('admin'),
  [
    body('chickenType').trim().notEmpty(),
    body('quantity').isInt({ min: 1 }),
    body('location').optional().isString(),
    body('tareWeight').optional().isFloat({ min: 0 }),
    body('netWeight').optional().isFloat({ min: 0 }),
    body('totalAmount').optional().isFloat({ min: 0 }),
    body('averageWeight').optional().isFloat({ min: 0 }),
    body('pricePerKg').optional().isFloat({ min: 0 }),
    body('reason').optional().trim(),
  ],
  validate,
  createStock
);

router.put('/:id', authorize('admin'), updateStock);
router.delete('/:id', authorize('admin'), deleteStock);

module.exports = router;
