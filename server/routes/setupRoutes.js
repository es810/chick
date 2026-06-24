const express = require('express');
const asyncHandler = require('../utils/asyncHandler');
const ApiError = require('../utils/apiError');
const { resetDatabase } = require('../utils/resetDatabase');
const { ensureAdminFromEnv } = require('../utils/bootstrapAdmin');

const router = express.Router();

const requireSetupSecret = (req, res, next) => {
  if (process.env.ALLOW_OPEN_BOOTSTRAP === 'true') {
    return next();
  }

  const expected = process.env.SETUP_SECRET?.trim();
  if (!expected) {
    throw new ApiError(503, 'Setup is disabled. Set SETUP_SECRET or ALLOW_OPEN_BOOTSTRAP on the server.');
  }
  const provided = req.header('x-setup-secret')?.trim();
  if (!provided || provided !== expected) {
    throw new ApiError(403, 'Invalid setup secret');
  }
  next();
};

router.post(
  '/reset',
  requireSetupSecret,
  asyncHandler(async (req, res) => {
    await resetDatabase({ bootstrap: true });
    res.json({
      success: true,
      message: 'Database wiped. Initial admin created from INITIAL_ADMIN_EMAIL / INITIAL_ADMIN_PASSWORD.',
    });
  })
);

router.post(
  '/ensure-admin',
  requireSetupSecret,
  asyncHandler(async (req, res) => {
    const result = await ensureAdminFromEnv();
    res.json({
      success: true,
      message: `Admin ${result.action}`,
      data: { email: result.email },
    });
  })
);

module.exports = router;
