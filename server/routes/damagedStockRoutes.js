const express = require('express');
const { body } = require('express-validator');
const { listHandler, createHandler } = require('../controllers/damagedStockController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.use(protect);
router.use(authorize('admin', 'employee'));

router.get('/', listHandler);
router.post(
  '/',
  authorize('admin'),
  [
    body('stockId').isMongoId(),
    body('quantity').isInt({ min: 1 }),
    body('reason').optional().trim(),
  ],
  validate,
  createHandler
);

module.exports = router;
