const mongoose = require('mongoose');
const User = require('../models/User');
const SalaryAdvance = require('../models/SalaryAdvance');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');
const { deductFromMainTreasury } = require('./treasuryService');

const monthRange = (date) => {
  const d = new Date(date);
  const start = new Date(d.getFullYear(), d.getMonth(), 1);
  const end = new Date(d.getFullYear(), d.getMonth() + 1, 1);
  return { start, end };
};

const getAdvancesTakenInMonth = async (employeeId, date) => {
  const { start, end } = monthRange(date);
  const agg = await SalaryAdvance.aggregate([
    {
      $match: {
        employeeId: new mongoose.Types.ObjectId(employeeId),
        advanceDate: { $gte: start, $lt: end },
      },
    },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);
  return agg[0]?.total || 0;
};

const listEmployeeAdvances = async (employeeId) => {
  const employee = await User.findOne({ _id: employeeId, role: 'employee' });
  if (!employee) throw new ApiError(404, 'Employee not found');

  const [advances, totalAgg] = await Promise.all([
    SalaryAdvance.find({ employeeId })
      .populate('createdBy', 'name')
      .sort({ advanceDate: -1, createdAt: -1 })
      .limit(100),
    SalaryAdvance.aggregate([
      { $match: { employeeId: new mongoose.Types.ObjectId(employeeId) } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]),
  ]);

  const totalAdvances = totalAgg[0]?.total || 0;

  return { employee, advances, totalAdvances };
};

const createSalaryAdvance = async (employeeId, data, user) => {
  const { advanceDate, amount, notes = '' } = data;

  if (!amount || amount <= 0) {
    throw new ApiError(400, 'Advance amount must be greater than zero');
  }

  const employee = await User.findOne({ _id: employeeId, role: 'employee' });
  if (!employee) throw new ApiError(404, 'Employee not found');

  const takenThisMonth = await getAdvancesTakenInMonth(employeeId, advanceDate);
  const remainingSalary = Math.max(0, (employee.salary || 0) - takenThisMonth);

  if (employee.salary > 0 && amount > remainingSalary) {
    throw new ApiError(400, 'Advance amount exceeds remaining salary for this month');
  }

  const movement = await deductFromMainTreasury(amount, user, {
    reason: `سلفة راتب — ${employee.name}`,
    employeeId: employee._id.toString(),
  });

  const advance = await SalaryAdvance.create({
    employeeId,
    advanceDate: new Date(advanceDate),
    amount,
    notes,
    treasuryMovementId: movement._id,
    createdBy: user._id,
  });

  await logAction(user._id, user.name, 'SALARY_ADVANCE', employee.name, { amount });

  return SalaryAdvance.findById(advance._id).populate('createdBy', 'name');
};

const sumAdvancesInMonth = async (year, month) => {
  const startOfMonth = new Date(year, month - 1, 1);
  const startOfNextMonth = new Date(year, month, 1);

  const agg = await SalaryAdvance.aggregate([
    { $match: { advanceDate: { $gte: startOfMonth, $lt: startOfNextMonth } } },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);

  return agg[0]?.total || 0;
};

module.exports = {
  listEmployeeAdvances,
  createSalaryAdvance,
  sumAdvancesInMonth,
  getAdvancesTakenInMonth,
};
