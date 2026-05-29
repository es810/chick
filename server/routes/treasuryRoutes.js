const express = require('express');
const { body } = require('express-validator');
const {
  getMainTreasuryHandler,
  getTreasurySummaryHandler,
  updateMainTreasuryHandler,
  addExternalRevenueHandler,
  withdrawFromTreasuryHandler,
  resetMainTreasuryHandler,
  listTreasuryEntriesHandler,
  createTreasuryEntryHandler,
  updateTreasuryEntryHandler,
  deleteTreasuryEntryHandler,
  listTreasuryEmployeesHandler,
} = require('../controllers/treasuryController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.use(protect);
router.use(authorize('admin'));

router.get('/summary', getTreasurySummaryHandler);
router.get('/', getMainTreasuryHandler);
router.patch(
  '/',
  [
    body('openingBalance').optional().isFloat(),
    body('balance').optional().isFloat(),
  ],
  validate,
  updateMainTreasuryHandler
);
router.post(
  '/external-revenue',
  [body('amount').isFloat({ min: 0.01 }), body('description').optional().isString()],
  validate,
  addExternalRevenueHandler
);
router.post(
  '/withdraw',
  [body('amount').isFloat({ min: 0.01 }), body('description').optional().isString()],
  validate,
  withdrawFromTreasuryHandler
);
router.post('/reset', resetMainTreasuryHandler);

router.get('/employees', listTreasuryEmployeesHandler);
router.get('/entries', listTreasuryEntriesHandler);
router.post(
  '/entries',
  [
    body('category').isIn(['external_revenue', 'withdrawal', 'loading', 'expense']),
    body('amount').isFloat({ min: 0.01 }),
    body('description').optional().isString(),
    body('employeeId').optional().isMongoId(),
  ],
  validate,
  createTreasuryEntryHandler
);
router.patch(
  '/entries/:id',
  [
    body('amount').optional().isFloat({ min: 0.01 }),
    body('description').optional().isString(),
  ],
  validate,
  updateTreasuryEntryHandler
);
router.delete('/entries/:id', deleteTreasuryEntryHandler);

module.exports = router;
