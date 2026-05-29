const express = require('express');
const {
  getSalesReport,
  getRevenueReport,
  getAuditLogs,
  getDashboard,
} = require('../controllers/reportController');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

router.use(protect);
router.use(authorize('admin'));

router.get('/dashboard', getDashboard);
router.get('/sales', getSalesReport);
router.get('/revenue', getRevenueReport);
router.get('/audit-logs', getAuditLogs);

module.exports = router;
