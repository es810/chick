const app = require('./app');
const mongoose = require('mongoose');
const connectDB = require('./config/db');
const { port, nodeEnv } = require('./config/env');
const logger = require('./utils/logger');
const User = require('./models/User');
const { ensureDemoUsers } = require('./utils/ensureUsers');

const MAX_DB_ATTEMPTS = nodeEnv === 'production' ? 12 : 6;
const DB_RETRY_MS = 5000;

async function ensureDemoUsersIfNeeded() {
  const adminExists = await User.exists({ email: 'admin@chickenfarm.com' });
  if (!adminExists) {
    logger.info('No admin user in database — creating demo logins...');
    await ensureDemoUsers();
    logger.info('Demo users ready: admin@chickenfarm.com / admin123');
  }
}

async function startMongoWithRetry() {
  for (let attempt = 1; attempt <= MAX_DB_ATTEMPTS; attempt += 1) {
    try {
      await connectDB();
      await ensureDemoUsersIfNeeded();
      return true;
    } catch (error) {
      logger.error(`MongoDB attempt ${attempt}/${MAX_DB_ATTEMPTS}: ${error.message}`);
      if (attempt >= MAX_DB_ATTEMPTS) {
        logger.error('MongoDB unavailable — retrying in background. Start MongoDB or check MONGODB_URI.');
        scheduleMongoReconnect();
        return false;
      }
      await new Promise((resolve) => setTimeout(resolve, DB_RETRY_MS));
    }
  }
  return false;
}

function scheduleMongoReconnect() {
  const timer = setInterval(async () => {
    if (mongoose.connection.readyState === 1) {
      clearInterval(timer);
      return;
    }
    try {
      await connectDB();
      await ensureDemoUsersIfNeeded();
      logger.info('MongoDB reconnected');
      clearInterval(timer);
    } catch (_) {
      // keep retrying
    }
  }, DB_RETRY_MS);
}

app.listen(port, '0.0.0.0', () => {
  logger.info(`Server listening on 0.0.0.0:${port} (${nodeEnv})`);
  startMongoWithRetry().catch((err) => logger.error(`MongoDB startup error: ${err.message}`));
});

process.on('unhandledRejection', (reason) => {
  logger.error(`Unhandled rejection: ${reason}`);
});
