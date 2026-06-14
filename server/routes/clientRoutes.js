const express = require('express');
const { body } = require('express-validator');
const {
  getClients,
  getClient,
  createClient,
  updateClient,
  deleteClient,
} = require('../controllers/clientController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.use(protect);

router.get('/', authorize('admin', 'employee'), getClients);
router.get('/:id', authorize('admin', 'employee'), getClient);

router.post(
  '/',
  authorize('admin'),
  [
    body('name').trim().notEmpty(),
    body('phone').trim().notEmpty(),
    body('address').optional().trim(),
    body('balance').optional().isFloat({ min: 0 }),
    body('email').trim().isEmail().normalizeEmail(),
    body('password').isLength({ min: 6 }),
  ],
  validate,
  createClient
);

router.put(
  '/:id',
  authorize('admin'),
  [
    body('name').optional().trim().notEmpty(),
    body('phone').optional().trim().notEmpty(),
    body('address').optional().trim(),
    body('balance').optional().isFloat({ min: 0 }),
    body('email').optional().trim().isEmail().normalizeEmail(),
    body('password').optional().isLength({ min: 6 }),
  ],
  validate,
  updateClient
);
router.delete('/:id', authorize('admin'), deleteClient);

module.exports = router;
