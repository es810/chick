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

module.exports = { bootstrapInitialAdmin };
