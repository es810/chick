const User = require('../models/User');
const logger = require('./logger');

/**
 * Creates the first admin only when the database has no users and
 * INITIAL_ADMIN_EMAIL + INITIAL_ADMIN_PASSWORD are set in the environment.
 */
const bootstrapInitialAdmin = async () => {
  const count = await User.countDocuments();
  if (count > 0) return false;

  const email = process.env.INITIAL_ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.INITIAL_ADMIN_PASSWORD;
  const name = process.env.INITIAL_ADMIN_NAME?.trim() || 'Admin';
  const phone = process.env.INITIAL_ADMIN_PHONE?.trim() || '0000000000';

  if (!email || !password) {
    logger.warn(
      'No users in database. Set INITIAL_ADMIN_EMAIL and INITIAL_ADMIN_PASSWORD to create the first admin, or run: npm run reset-db'
    );
    return false;
  }

  await User.create({
    name,
    phone,
    email,
    password,
    role: 'admin',
  });

  logger.info(`Initial admin created: ${email}`);
  return true;
};

/**
 * Creates or updates the admin from INITIAL_ADMIN_* env vars.
 * Use when login fails after deploy or password change on Railway.
 */
const ensureAdminFromEnv = async () => {
  const email = process.env.INITIAL_ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.INITIAL_ADMIN_PASSWORD;
  const name = process.env.INITIAL_ADMIN_NAME?.trim() || 'Admin';
  const phone = process.env.INITIAL_ADMIN_PHONE?.trim() || '0000000000';

  if (!email || !password) {
    throw new Error('Set INITIAL_ADMIN_EMAIL and INITIAL_ADMIN_PASSWORD in the environment.');
  }

  let user = await User.findOne({ email }).select('+password');

  if (user) {
    user.name = name;
    user.phone = phone;
    user.password = password;
    user.role = 'admin';
    user.isActive = true;
    await user.save();
    logger.info(`Admin account updated: ${email}`);
    return { action: 'updated', email };
  }

  await User.create({
    name,
    phone,
    email,
    password,
    role: 'admin',
  });

  logger.info(`Admin account created: ${email}`);
  return { action: 'created', email };
};

module.exports = { bootstrapInitialAdmin, ensureAdminFromEnv };
