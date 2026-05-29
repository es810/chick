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
  ],
  validate,
  createClient
);

router.put('/:id', authorize('admin'), updateClient);
router.delete('/:id', authorize('admin'), deleteClient);

module.exports = router;
