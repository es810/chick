require('./mongoDns');
const mongoose = require('mongoose');
const { mongoUri, nodeEnv } = require('./env');
const logger = require('../utils/logger');

const PLACEHOLDER_PATTERNS = ['<user>', '<password>', 'cluster.mongodb.net'];

const isPlaceholderUri = (uri) =>
  PLACEHOLDER_PATTERNS.some((pattern) => uri.includes(pattern));

const connectDB = async () => {
  if (isPlaceholderUri(mongoUri)) {
    logger.error('MongoDB URI is still the placeholder from .env.example.');
    logger.error('Set MONGODB_URI in server/.env to one of:');
    logger.error('  Local:  mongodb://127.0.0.1:27017/chicken_farm');
    logger.error('  Atlas:  mongodb+srv://USER:PASS@your-cluster.mongodb.net/chicken_farm');
    throw new Error('MongoDB URI is still a placeholder — set MONGODB_URI in Railway variables');
  }

  // Already connected
  if (mongoose.connection.readyState === 1) {
    return;
  }

  // Wait if a connection attempt is in progress
  if (mongoose.connection.readyState === 2) {
    await new Promise((resolve, reject) => {
      const onOpen = () => {
        cleanup();
        resolve();
      };
      const onErr = (err) => {
        cleanup();
        reject(err);
      };
      const cleanup = () => {
        mongoose.connection.off('connected', onOpen);
        mongoose.connection.off('error', onErr);
      };
      mongoose.connection.once('connected', onOpen);
      mongoose.connection.once('error', onErr);
    });
    return;
  }

  try {
    await mongoose.connect(mongoUri, {
      serverSelectionTimeoutMS: nodeEnv === 'production' ? 30000 : 10000,
      maxPoolSize: 10,
    });
    logger.info(`MongoDB connected (${nodeEnv})`);
  } catch (error) {
    logger.error(`MongoDB connection error: ${error.message}`);

    if (mongoUri.includes('127.0.0.1') || mongoUri.includes('localhost')) {
      logger.error('Local MongoDB is not running. Start it with (Admin PowerShell):');
      logger.error('  net start MongoDB');
    } else if (error.message.includes('querySrv ECONNREFUSED')) {
      logger.error('Cannot reach MongoDB Atlas. Check Network Access (0.0.0.0/0) and the URI.');
    }

    throw error;
  }
};

let reconnectTimer = null;

const startDisconnectWatch = () => {
  mongoose.connection.on('disconnected', () => {
    logger.warn('MongoDB disconnected — will retry connection');
    if (reconnectTimer) return;
    reconnectTimer = setInterval(async () => {
      if (mongoose.connection.readyState === 1) {
        clearInterval(reconnectTimer);
        reconnectTimer = null;
        return;
      }
      try {
        await connectDB();
        logger.info('MongoDB reconnected after disconnect');
        clearInterval(reconnectTimer);
        reconnectTimer = null;
      } catch (_) {
        // keep retrying
      }
    }, 5000);
  });

  mongoose.connection.on('reconnected', () => {
    logger.info('MongoDB reconnected');
  });
};

module.exports = connectDB;
module.exports.startDisconnectWatch = startDisconnectWatch;
