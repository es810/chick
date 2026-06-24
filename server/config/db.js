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

  try {
    await mongoose.connect(mongoUri, {
      serverSelectionTimeoutMS: nodeEnv === 'production' ? 30000 : 5000,
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

module.exports = connectDB;
