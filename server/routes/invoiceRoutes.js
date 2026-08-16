const express = require('express');
const { body } = require('express-validator');
const {
  getInvoices,
  getInvoice,
  createInvoiceHandler,
  updateInvoice,
  deleteInvoiceHandler,
} = require('../controllers/invoiceController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.use(protect);

router.get('/', getInvoices);
router.get('/:id', getInvoice);

router.post(
  '/',
  authorize('admin', 'employee'),
  [
    body('clientId').notEmpty().isMongoId(),
    body('items').isArray({ min: 1 }),
    body('items.*.chickenType').trim().notEmpty(),
    body('items.*.quantity').isInt({ min: 1 }),
    body('paymentStatus').optional().isIn(['pending', 'partial', 'paid']),
    body('grossWeight').optional().isFloat({ min: 0 }),
    body('tareWeight').optional().isFloat({ min: 0 }),
    body('itemCount').optional().isInt({ min: 1 }),
  ],
  validate,
  createInvoiceHandler
);

router.patch(
  '/:id',
  authorize('admin', 'employee'),
  [
    body('paymentStatus').optional().isIn(['pending', 'partial', 'paid']),
    body('clientId').optional().isMongoId(),
    body('notes').optional().isString(),
    body('items').optional().isArray({ min: 1 }),
    body('items.*.chickenType').optional().trim().notEmpty(),
    body('items.*.quantity').optional().isInt({ min: 1 }),
    body('grossWeight').optional().isFloat({ min: 0 }),
    body('tareWeight').optional().isFloat({ min: 0 }),
    body('itemCount').optional().isInt({ min: 1 }),
  ],
  validate,
  updateInvoice
);

router.delete('/:id', authorize('admin', 'employee'), deleteInvoiceHandler);

module.exports = router;
