const app = require('./app');
const mongoose = require('mongoose');
const connectDB = require('./config/db');
const { port, nodeEnv } = require('./config/env');
const logger = require('./utils/logger');
const { bootstrapInitialAdmin } = require('./utils/bootstrapAdmin');

const MAX_DB_ATTEMPTS = nodeEnv === 'production' ? 12 : 6;
const DB_RETRY_MS = 5000;

async function bootstrapIfEmpty() {
  await bootstrapInitialAdmin();
}

async function startMongoWithRetry() {
  for (let attempt = 1; attempt <= MAX_DB_ATTEMPTS; attempt += 1) {
    try {
      await connectDB();
      await bootstrapIfEmpty();
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
      await bootstrapIfEmpty();
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
