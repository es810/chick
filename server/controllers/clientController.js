const Client = require('../models/Client');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { logAction } = require('../services/auditService');

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
    Client.find(query).sort({ createdAt: -1 }).skip(skip).limit(parseInt(limit)),
    Client.countDocuments(query),
  ]);

  res.json({
    success: true,
    data: clients,
    pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) },
  });
});

const getClient = asyncHandler(async (req, res) => {
  const client = await Client.findById(req.params.id);
  if (!client) throw new ApiError(404, 'Client not found');
  res.json({ success: true, data: client });
});

const createClient = asyncHandler(async (req, res) => {
  const client = await Client.create(req.body);
  await logAction(req.user._id, req.user.name, 'CREATE_CLIENT', client.name);
  res.status(201).json({ success: true, data: client });
});

const updateClient = asyncHandler(async (req, res) => {
  const client = await Client.findByIdAndUpdate(req.params.id, req.body, {
    new: true,
    runValidators: true,
  });
  if (!client) throw new ApiError(404, 'Client not found');
  await logAction(req.user._id, req.user.name, 'UPDATE_CLIENT', client.name);
  res.json({ success: true, data: client });
});

const deleteClient = asyncHandler(async (req, res) => {
  const client = await Client.findByIdAndDelete(req.params.id);
  if (!client) throw new ApiError(404, 'Client not found');
  await logAction(req.user._id, req.user.name, 'DELETE_CLIENT', client.name);
  res.json({ success: true, message: 'Client deleted' });
});

module.exports = { getClients, getClient, createClient, updateClient, deleteClient };
