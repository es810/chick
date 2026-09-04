const ApiError = require('../utils/apiError');
const logger = require('../utils/logger');

const errorHandler = (err, req, res, next) => {
  let statusCode = err.statusCode || 500;
  let message = err.message || 'Internal Server Error';

  if (err.name === 'ValidationError') {
    statusCode = 400;
    message = Object.values(err.errors)
      .map((e) => e.message)
      .join(', ');
  }

  if (err.code === 11000) {
    statusCode = 400;
    const field = Object.keys(err.keyPattern || {})[0];
    if (field === 'employeeLedgerId') {
      message = 'تعارض أثناء تسجيل دفع المورد. حدّث كشف الحساب وحاول مرة أخرى.';
    } else {
      message = `${field} already exists`;
    }
  }

  if (err.name === 'CastError') {
    statusCode = 400;
    message = 'Invalid ID format';
  }

  if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    message = 'Session expired. Please login again.';
  }

  if (err.name === 'MongooseError' && /buffering timed out/i.test(err.message)) {
    statusCode = 503;
    message = 'Database is not connected. Start MongoDB or check MONGODB_URI.';
  }

  if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    message = 'Invalid token';
  }

  if (
    err.name === 'MongoServerError' &&
    /WriteConflict|TransientTransactionError/i.test(err.message || '')
  ) {
    statusCode = 409;
    message = 'تعارض أثناء الحفظ. حاول مرة أخرى.';
  }

  if (
    statusCode === 500 &&
    /NoTransactionInProgress|Cannot call abortTransaction|transaction number/i.test(
      err.message || ''
    )
  ) {
    statusCode = 409;
    message = 'تعارض أثناء الحفظ. حاول مرة أخرى.';
  }

  if (statusCode === 500) {
    logger.error(`${err.stack || err.message}`);
  }

  res.status(statusCode).json({
    success: false,
    message,
    errors: err.errors || undefined,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
};

module.exports = errorHandler;
