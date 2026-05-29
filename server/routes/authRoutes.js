const express = require('express');
const { body } = require('express-validator');
const { login, register, getMe, logout } = require('../controllers/authController');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.post(
  '/login',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty().withMessage('Password required'),
  ],
  validate,
  login
);

router.post(
  '/register',
  protect,
  authorize('admin'),
  [
    body('name').trim().notEmpty(),
    body('phone').trim().notEmpty(),
    body('email').isEmail().normalizeEmail(),
    body('password').isLength({ min: 6 }),
    body('role').isIn(['admin', 'employee', 'client']),
  ],
  validate,
  register
);

router.get('/me', protect, getMe);
router.post('/logout', protect, logout);

module.exports = router;
