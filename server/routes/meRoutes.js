const express = require('express');
const { body } = require('express-validator');
const { getMyLedger, addMyExpense, addMyDebt } = require('../controllers/meController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.use(protect, authorize('employee'));

const ledgerValidation = [
  body('amount').isFloat({ min: 0.01 }).withMessage('Amount must be greater than 0'),
  body('description').trim().notEmpty().withMessage('Description is required'),
];

const debtValidation = [
  ...ledgerValidation,
  body('supplierId').isMongoId().withMessage('Supplier is required'),
];

router.get('/ledger', getMyLedger);
router.post('/ledger/expense', ledgerValidation, validate, addMyExpense);
router.post('/ledger/debt', debtValidation, validate, addMyDebt);

module.exports = router;
