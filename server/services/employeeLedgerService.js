const mongoose = require('mongoose');
const User = require('../models/User');
const EmployeeLedger = require('../models/EmployeeLedger');
const { getTreasurySummary } = require('./treasuryService');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');

const getEmployeeLedger = async (employeeId) => {
  const employee = await User.findOne({ _id: employeeId, role: 'employee' });
  if (!employee) throw new ApiError(404, 'Employee not found');

  const [entries, totals] = await Promise.all([
    EmployeeLedger.find({ employeeId })
      .populate('createdBy', 'name')
      .sort({ createdAt: -1 })
      .limit(100),
    EmployeeLedger.aggregate([
      { $match: { employeeId: new mongoose.Types.ObjectId(employeeId) } },
      {
        $group: {
          _id: '$type',
          total: { $sum: '$amount' },
          count: { $sum: 1 },
        },
      },
    ]),
  ]);

  let totalExpenses = 0;
  let totalDebt = 0;
  for (const row of totals) {
    if (row._id === 'expense') totalExpenses = row.total;
    if (row._id === 'debt') totalDebt = row.total;
  }

  return { employee, entries, totalExpenses, totalDebt };
};

const addLedgerEntry = async (employeeId, type, amount, description, user) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const employee = await User.findOne({ _id: employeeId, role: 'employee' }).session(session);
    if (!employee) throw new ApiError(404, 'Employee not found');

    const summary = await getTreasurySummary();
    if (summary.balance < amount) {
      throw new ApiError(400, 'Insufficient main treasury balance');
    }

    const [entry] = await EmployeeLedger.create(
      [
        {
          employeeId,
          type,
          amount,
          description,
          createdBy: user._id,
        },
      ],
      { session }
    );

    await session.commitTransaction();

    const action = type === 'expense' ? 'ADD_EMPLOYEE_EXPENSE' : 'ADD_EMPLOYEE_DEBT';
    await logAction(user._id, user.name, action, employee.name, { amount, description });

    return EmployeeLedger.findById(entry._id).populate('createdBy', 'name');
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

module.exports = { getEmployeeLedger, addLedgerEntry };
