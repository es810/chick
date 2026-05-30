const express = require('express');
const { body } = require('express-validator');
const {
  getEmployees,
  createEmployee,
  updateEmployee,
  deleteEmployee,
} = require('../controllers/employeeController');
const { getLedger, addExpense, addDebt } = require('../controllers/employeeLedgerController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.use(protect, authorize('admin'));

router.get('/', getEmployees);

const ledgerValidation = [
  body('amount').isFloat({ min: 0.01 }).withMessage('Amount must be greater than 0'),
  body('description').trim().notEmpty().withMessage('Description is required'),
];

router.get('/:id/ledger', getLedger);
router.post('/:id/ledger/expense', ledgerValidation, validate, addExpense);
router.post('/:id/ledger/debt', ledgerValidation, validate, addDebt);

router.post(
  '/',
  [
    body('name').trim().notEmpty(),
    body('phone').trim().notEmpty(),
    body('email').isEmail().normalizeEmail(),
    body('password').isLength({ min: 6 }),
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
  ],
  validate,
  updateEmployee
);
router.delete('/:id', deleteEmployee);

module.exports = router;
