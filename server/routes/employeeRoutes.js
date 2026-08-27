const express = require('express');
const { body } = require('express-validator');
const {
  getEmployees,
  createEmployee,
  updateEmployee,
  deleteEmployee,
} = require('../controllers/employeeController');
const { createEmployeeTreasuryTransfer } = require('../controllers/employeeTreasuryController');
const { getLedger, addExpense, addDebt, addSalaryAdvance, getTreasuryStatement } = require('../controllers/employeeLedgerController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.use(protect, authorize('admin'));

router.get('/', getEmployees);

router.post(
  '/treasury-transfers',
  [
    body('fromEmployeeId').isMongoId().withMessage('Source employee is required'),
    body('toEmployeeId').isMongoId().withMessage('Destination employee is required'),
    body('amount').isFloat({ min: 0.01 }).withMessage('Amount must be greater than 0'),
    body('notes').optional().trim(),
  ],
  validate,
  createEmployeeTreasuryTransfer
);

const ledgerValidation = [
  body('amount').isFloat({ min: 0.01 }).withMessage('Amount must be greater than 0'),
  body('description').trim().notEmpty().withMessage('Description is required'),
];

const debtValidation = [
  ...ledgerValidation,
  body('supplierId').isMongoId().withMessage('Supplier is required'),
  body('amountDeducted').optional().isFloat({ min: 0 }),
];

router.get('/:id/ledger', getLedger);
router.get('/:id/treasury/statement', getTreasuryStatement);
router.post('/:id/ledger/expense', ledgerValidation, validate, addExpense);
router.post('/:id/ledger/debt', debtValidation, validate, addDebt);
router.post(
  '/:id/advances',
  [
    body('advanceDate').isISO8601(),
    body('amount').isFloat({ min: 0.01 }),
    body('notes').optional().trim(),
  ],
  validate,
  addSalaryAdvance
);

router.post(
  '/',
  [
    body('name').trim().notEmpty(),
    body('phone').trim().notEmpty(),
    body('email').isEmail().normalizeEmail(),
    body('password').isLength({ min: 6 }),
    body('salary').optional().isFloat({ min: 0 }),
  ],
  validate,
  createEmployee
);

router.put(
  '/:id',
  [
    body('name').optional().trim().notEmpty(),
    body('phone').optional().trim().notEmpty(),
    body('email').optional().isEmail().normalizeEmail(),
    body('password').optional().isLength({ min: 6 }),
    body('isActive').optional().isBoolean(),
    body('salary').optional().isFloat({ min: 0 }),
  ],
  validate,
  updateEmployee
);
router.delete('/:id', deleteEmployee);

module.exports = router;
