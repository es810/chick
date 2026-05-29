const AuditLog = require('../models/AuditLog');

const logAction = async (userId, userName, action, target, details = {}, ip = null) => {
  try {
    await AuditLog.create({ userId, userName, action, target, details, ip });
  } catch (err) {
    console.error('Audit log failed:', err.message);
  }
};

module.exports = { logAction };
