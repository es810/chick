const User = require('../models/User');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { logAction } = require('../services/auditService');
const { attachTreasuryBalances } = require('../services/employeeTreasuryService');

const getEmployees = asyncHandler(async (req, res) => {
  const { search, page = 1, limit = 20 } = req.query;
  const query = { role: 'employee' };

  if (search) {
    query.$or = [
      { name: { $regex: search, $options: 'i' } },
      { email: { $regex: search, $options: 'i' } },
    ];
  }

  const skip = (parseInt(page) - 1) * parseInt(limit);
  const [employees, total] = await Promise.all([
    User.find(query).select('-password').sort({ createdAt: -1 }).skip(skip).limit(parseInt(limit)),
    User.countDocuments(query),
  ]);

  const data = await attachTreasuryBalances(employees);

  res.json({
    success: true,
    data,
    pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) },
  });
});

const createEmployee = asyncHandler(async (req, res) => {
  const { name, phone, email, password, salary = 0 } = req.body;
  const exists = await User.findOne({ email });
  if (exists) throw new ApiError(400, 'Email already exists');

  const employee = await User.create({
    name,
    phone,
    email,
    password,
    role: 'employee',
    salary,
  });
  await logAction(req.user._id, req.user.name, 'CREATE_EMPLOYEE', employee.name);
  res.status(201).json({ success: true, data: employee });
});

const updateEmployee = asyncHandler(async (req, res) => {
  const { name, phone, email, password, isActive, salary } = req.body;
  const employee = await User.findOne({ _id: req.params.id, role: 'employee' });
  if (!employee) throw new ApiError(404, 'Employee not found');

  if (email && email !== employee.email) {
    const exists = await User.findOne({ email });
    if (exists) throw new ApiError(400, 'Email already exists');
    employee.email = email;
  }
  if (name !== undefined) employee.name = name;
  if (phone !== undefined) employee.phone = phone;
  if (isActive !== undefined) employee.isActive = isActive;
  if (salary !== undefined) employee.salary = salary;
  if (password) employee.password = password;

  await employee.save();
  await logAction(req.user._id, req.user.name, 'UPDATE_EMPLOYEE', employee.name);
  res.json({ success: true, data: employee });
});

const deleteEmployee = asyncHandler(async (req, res) => {
  const employee = await User.findOneAndUpdate(
    { _id: req.params.id, role: 'employee' },
    { isActive: false },
    { new: true }
  );
  if (!employee) throw new ApiError(404, 'Employee not found');
  await logAction(req.user._id, req.user.name, 'DEACTIVATE_EMPLOYEE', employee.name);
  res.json({ success: true, message: 'Employee deactivated' });
});

module.exports = { getEmployees, createEmployee, updateEmployee, deleteEmployee };
