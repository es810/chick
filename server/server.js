const app = require('./app');
const connectDB = require('./config/db');
const { port } = require('./config/env');
const logger = require('./utils/logger');

connectDB().then(() => {
  app.listen(port, '0.0.0.0', () => {
    logger.info(`Server running on port ${port}`);
  });
});
