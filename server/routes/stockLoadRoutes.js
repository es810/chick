const express = require('express');
const { param } = require('express-validator');
const { listHandler, finishHandler } = require('../controllers/stockLoadController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.use(protect);
router.use(authorize('admin', 'employee'));

router.get('/', listHandler);
router.post(
  '/:id/finish',
  authorize('admin'),
  [param('id').isMongoId()],
  validate,
  finishHandler
);

module.exports = router;
