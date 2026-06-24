const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const mongoose = require('mongoose');
const errorHandler = require('./middleware/errorHandler');
const requireDb = require('./middleware/requireDb');

const authRoutes = require('./routes/authRoutes');
const clientRoutes = require('./routes/clientRoutes');
const supplierRoutes = require('./routes/supplierRoutes');
const stockRoutes = require('./routes/stockRoutes');
const invoiceRoutes = require('./routes/invoiceRoutes');
const reportRoutes = require('./routes/reportRoutes');
const employeeRoutes = require('./routes/employeeRoutes');
const treasuryRoutes = require('./routes/treasuryRoutes');
const collectionRoutes = require('./routes/collectionRoutes');
const damagedStockRoutes = require('./routes/damagedStockRoutes');
const meRoutes = require('./routes/meRoutes');
const setupRoutes = require('./routes/setupRoutes');

const app = express();

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(morgan('dev'));

app.get('/health', (req, res) => {
  const dbConnected = mongoose.connection.readyState === 1;
  res.status(200).json({
    success: true,
    message: 'Chicken Farm API is running',
    db: dbConnected ? 'connected' : 'connecting',
  });
});

app.get('/api', (req, res) => {
  res.json({
    success: true,
    message: 'Chicken Farm API — use /api/auth/login, /api/stock, etc.',
    health: '/health',
  });
});

app.use('/api/setup', requireDb, setupRoutes);
app.use('/api', requireDb);

app.use('/api/auth', authRoutes);
app.use('/api/clients', clientRoutes);
app.use('/api/suppliers', supplierRoutes);
app.use('/api/stock', stockRoutes);
app.use('/api/invoices', invoiceRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/treasury', treasuryRoutes);
app.use('/api/collections', collectionRoutes);
app.use('/api/damaged-stock', damagedStockRoutes);
app.use('/api/me', meRoutes);
app.use('/api/employees', employeeRoutes);

app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

app.use(errorHandler);

module.exports = app;
