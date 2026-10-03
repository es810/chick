const express = require('express');
const { param } = require('express-validator');
const {
  listHandler,
  finishHandler,
  statementHandler,
} = require('../controllers/stockLoadController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.use(protect);
router.use(authorize('admin', 'employee'));

router.get('/', listHandler);
router.get(
  '/:id/statement',
  [param('id').isMongoId()],
  validate,
  statementHandler
);
router.post(
  '/:id/finish',
  authorize('admin', 'employee'),
  [param('id').isMongoId()],
  validate,
  finishHandler
);

module.exports = router;
