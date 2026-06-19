const express = require('express');
const { body } = require('express-validator');
const {
  listCollectionInvoicesHandler,
  listCollectionEmployeesHandler,
  createCollectionInvoiceHandler,
  updateCollectionInvoiceHandler,
  deleteCollectionInvoiceHandler,
} = require('../controllers/collectionController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.use(protect);
router.use(authorize('admin', 'employee'));

const collectionBodyValidation = [
  body('clientId').isMongoId(),
  body('employeeId').isMongoId(),
  body('collectionDate').isISO8601(),
  body('amountPaid').isFloat({ min: 0.01 }),
  body('amountDeducted').isFloat({ min: 0 }),
  body('balanceBefore').isFloat({ min: 0 }),
  body('balanceAfter').isFloat({ min: 0 }),
];

router.get('/', listCollectionInvoicesHandler);
router.get('/employees', listCollectionEmployeesHandler);
router.post('/', collectionBodyValidation, validate, createCollectionInvoiceHandler);
router.patch('/:id', collectionBodyValidation, validate, updateCollectionInvoiceHandler);
router.delete('/:id', deleteCollectionInvoiceHandler);

module.exports = router;
