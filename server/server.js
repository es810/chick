const app = require('./app');
const connectDB = require('./config/db');
const { port, nodeEnv } = require('./config/env');
const logger = require('./utils/logger');

const MAX_DB_ATTEMPTS = nodeEnv === 'production' ? 12 : 1;
const DB_RETRY_MS = 5000;

async function startMongoWithRetry() {
  for (let attempt = 1; attempt <= MAX_DB_ATTEMPTS; attempt += 1) {
    try {
      await connectDB();
      return;
    } catch (error) {
      logger.error(`MongoDB attempt ${attempt}/${MAX_DB_ATTEMPTS}: ${error.message}`);
      if (attempt >= MAX_DB_ATTEMPTS) {
        logger.error('MongoDB unavailable — API stays up; fix MONGODB_URI or Atlas network access.');
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, DB_RETRY_MS));
    }
  }
}

app.listen(port, '0.0.0.0', () => {
  logger.info(`Server listening on 0.0.0.0:${port} (${nodeEnv})`);
  startMongoWithRetry().catch((err) => logger.error(`MongoDB startup error: ${err.message}`));
});

process.on('unhandledRejection', (reason) => {
  logger.error(`Unhandled rejection: ${reason}`);
});
