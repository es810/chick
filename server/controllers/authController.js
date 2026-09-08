const jwt = require('jsonwebtoken');
const User = require('../models/User');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { jwtSecret, jwtExpiresIn } = require('../config/env');
const { logAction } = require('../services/auditService');

const signToken = (id) => jwt.sign({ id }, jwtSecret, { expiresIn: jwtExpiresIn });

const login = asyncHandler(async (req, res) => {
  const email = req.body.email?.trim().toLowerCase();
  const { password } = req.body;

  const user = await User.findOne({ email }).select('+password');
  if (!user || !(await user.comparePassword(password))) {
    throw new ApiError(401, 'Invalid email or password');
  }

  if (!user.isActive) {
    throw new ApiError(401, 'Account is deactivated');
  }

  const token = signToken(user._id);

  await logAction(user._id, user.name, 'LOGIN', 'auth', {}, req.ip);

  res.json({
    success: true,
    data: {
      user: user.toJSON(),
      token,
      expiresIn: jwtExpiresIn,
    },
  });
});

const register = asyncHandler(async (req, res) => {
  const { name, phone, email, password, role } = req.body;

  const exists = await User.findOne({ email });
  if (exists) throw new ApiError(400, 'Email already registered');

  const user = await User.create({ name, phone, email, password, role });

  await logAction(req.user._id, req.user.name, 'REGISTER_USER', email, { role });

  res.status(201).json({ success: true, data: user });
});

const getMe = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user._id).populate('clientProfile');
  res.json({ success: true, data: user });
});

const updateMe = asyncHandler(async (req, res) => {
  const { name, phone, currentPassword, newPassword } = req.body;
  const user = await User.findById(req.user._id).select('+password');
  if (!user) throw new ApiError(404, 'User not found');

  if (name !== undefined) {
    const trimmed = String(name).trim();
    if (!trimmed) throw new ApiError(400, 'Name is required');
    user.name = trimmed;
  }

  if (phone !== undefined) {
    const trimmed = String(phone).trim();
    if (!trimmed) throw new ApiError(400, 'Phone is required');
    user.phone = trimmed;
  }

  if (newPassword !== undefined && newPassword !== null && String(newPassword).length > 0) {
    if (!currentPassword) {
      throw new ApiError(400, 'Current password is required');
    }
    if (!(await user.comparePassword(currentPassword))) {
      throw new ApiError(401, 'Current password is incorrect');
    }
    if (String(newPassword).length < 6) {
      throw new ApiError(400, 'Password must be at least 6 characters');
    }
    user.password = newPassword;
  }

  await user.save();
  await logAction(user._id, user.name, 'UPDATE_PROFILE', 'auth', {
    nameChanged: name !== undefined,
    phoneChanged: phone !== undefined,
    passwordChanged: Boolean(newPassword),
  }, req.ip);

  res.json({ success: true, data: user.toJSON() });
});

const logout = asyncHandler(async (req, res) => {
  await logAction(req.user._id, req.user.name, 'LOGOUT', 'auth', {}, req.ip);
  res.json({ success: true, message: 'Logged out successfully' });
});

module.exports = { login, register, getMe, updateMe, logout };
