require('dotenv').config();

const nodeEnv = process.env.NODE_ENV || 'development';
const jwtSecret = process.env.JWT_SECRET || 'dev-secret-change-me';
const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/chicken_farm';

if (nodeEnv === 'production') {
  if (!process.env.JWT_SECRET || jwtSecret === 'dev-secret-change-me') {
    throw new Error('JWT_SECRET must be set in production');
  }
  if (!process.env.MONGODB_URI) {
    throw new Error('MONGODB_URI must be set in production (use MongoDB Atlas)');
  }
}

module.exports = {
  port: process.env.PORT || 3000,
  nodeEnv,
  mongoUri,
  jwtSecret,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS, 10) || 12,
};
