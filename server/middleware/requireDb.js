const mongoose = require('mongoose');

/** Reject API calls when MongoDB is not connected (avoids 10s buffering timeout). */
const requireDb = (req, res, next) => {
  if (mongoose.connection.readyState === 1) {
    return next();
  }
  return res.status(503).json({
    success: false,
    message:
      'Database is not connected. Start MongoDB locally or check MONGODB_URI on the server.',
  });
};

module.exports = requireDb;
