const express = require('express');
const { body, param } = require('express-validator');
const {
  listHandler,
  createHandler,
  writeOffHandler,
} = require('../controllers/damagedStockController');
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
    body('quantity').optional().isInt({ min: 0 }),
    body('netWeight').optional().isFloat({ min: 0 }),
    body('reason').optional().trim(),
    body().custom((_, { req }) => {
      const qty = parseInt(req.body.quantity, 10) || 0;
      const kg = Number(req.body.netWeight) || 0;
      if (qty <= 0 && kg <= 0) {
        throw new Error('Quantity or weight is required');
      }
      return true;
    }),
  ],
  validate,
  createHandler
);
router.patch(
  '/:id/write-off',
  authorize('admin'),
  [param('id').isMongoId()],
  validate,
  writeOffHandler
);

module.exports = router;
