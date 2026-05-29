const jwt = require('jsonwebtoken');
const User = require('../models/User');
const ApiError = require('../utils/apiError');
const { jwtSecret } = require('../config/env');
const asyncHandler = require('../utils/asyncHandler');

const protect = asyncHandler(async (req, res, next) => {
  let token;
  if (req.headers.authorization?.startsWith('Bearer ')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    throw new ApiError(401, 'Not authorized. Please login.');
  }

  const decoded = jwt.verify(token, jwtSecret);
  const user = await User.findById(decoded.id).select('+password');

  if (!user || !user.isActive) {
    throw new ApiError(401, 'User not found or inactive.');
  }

  req.user = user;
  next();
});

const authorize = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user.role)) {
    throw new ApiError(403, `Role '${req.user.role}' is not authorized.`);
  }
  next();
};

module.exports = { protect, authorize };
