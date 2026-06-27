const Client = require('../models/Client');
const User = require('../models/User');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { logAction } = require('../services/auditService');
const { getClientStatement } = require('../services/accountStatementService');

const formatClient = (client) => {
  const obj = client.toObject ? client.toObject() : client;
  return {
    ...obj,
    email: client.userId?.email ?? null,
  };
};

const getClients = asyncHandler(async (req, res) => {
  const { search, page = 1, limit = 20 } = req.query;
  const query = {};

  if (search) {
    query.$or = [
      { name: { $regex: search, $options: 'i' } },
      { phone: { $regex: search, $options: 'i' } },
    ];
  }

  const skip = (parseInt(page) - 1) * parseInt(limit);
  const [clients, total] = await Promise.all([
    Client.find(query)
      .populate('userId', 'email')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit)),
    Client.countDocuments(query),
  ]);

  res.json({
    success: true,
    data: clients.map(formatClient),
    pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) },
  });
});

const getClient = asyncHandler(async (req, res) => {
  const client = await Client.findById(req.params.id).populate('userId', 'email');
  if (!client) throw new ApiError(404, 'Client not found');
  res.json({ success: true, data: formatClient(client) });
});

const getClientAccountStatement = asyncHandler(async (req, res) => {
  const data = await getClientStatement(req.params.id);
  res.json({ success: true, data });
});

const createClient = asyncHandler(async (req, res) => {
  const { name, phone, address = '', balance = 0, email, password } = req.body;

  const exists = await User.findOne({ email });
  if (exists) throw new ApiError(400, 'Email already registered');

  const user = await User.create({
    name,
    phone,
    email,
    password,
    role: 'client',
  });

  const client = await Client.create({
    name,
    phone,
    address,
    balance,
    userId: user._id,
  });

  user.clientProfile = client._id;
  await user.save();

  await client.populate('userId', 'email');
  await logAction(req.user._id, req.user.name, 'CREATE_CLIENT', client.name);
  res.status(201).json({ success: true, data: formatClient(client) });
});

const updateClient = asyncHandler(async (req, res) => {
  const { name, phone, address, balance, email, password } = req.body;

  const client = await Client.findById(req.params.id);
  if (!client) throw new ApiError(404, 'Client not found');

  if (name !== undefined) client.name = name;
  if (phone !== undefined) client.phone = phone;
  if (address !== undefined) client.address = address;
  if (balance !== undefined) client.balance = balance;

  if (client.userId) {
    const user = await User.findById(client.userId).select('+password');
    if (!user) throw new ApiError(404, 'Linked user not found');

    if (email && email !== user.email) {
      const exists = await User.findOne({ email });
      if (exists) throw new ApiError(400, 'Email already registered');
      user.email = email;
    }
    if (name !== undefined) user.name = name;
    if (phone !== undefined) user.phone = phone;
    if (password) user.password = password;
    await user.save();
  } else if (email && password) {
    const exists = await User.findOne({ email });
    if (exists) throw new ApiError(400, 'Email already registered');

    const user = await User.create({
      name: client.name,
      phone: client.phone,
      email,
      password,
      role: 'client',
      clientProfile: client._id,
    });
    client.userId = user._id;
  }

  await client.save();
  await client.populate('userId', 'email');
  await logAction(req.user._id, req.user.name, 'UPDATE_CLIENT', client.name);
  res.json({ success: true, data: formatClient(client) });
});

const deleteClient = asyncHandler(async (req, res) => {
  const client = await Client.findById(req.params.id);
  if (!client) throw new ApiError(404, 'Client not found');

  if (client.userId) {
    await User.findByIdAndDelete(client.userId);
  }
  await Client.findByIdAndDelete(req.params.id);

  await logAction(req.user._id, req.user.name, 'DELETE_CLIENT', client.name);
  res.json({ success: true, message: 'Client deleted' });
});

module.exports = {
  getClients,
  getClient,
  getClientAccountStatement,
  createClient,
  updateClient,
  deleteClient,
};
