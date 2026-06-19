const mongoose = require('mongoose');
const Stock = require('../models/Stock');
const DamagedStock = require('../models/DamagedStock');
const StockMovement = require('../models/StockMovement');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');

const listDamagedStock = async () => {
  return DamagedStock.find()
    .populate('recordedBy', 'name')
    .populate('stockId', 'chickenType location')
    .sort({ createdAt: -1 })
    .limit(500);
};

const getDamagedStockSummary = async () => {
  const [agg] = await DamagedStock.aggregate([
    { $group: { _id: null, totalQuantity: { $sum: '$quantity' }, entryCount: { $sum: 1 } } },
  ]);
  return {
    totalQuantity: agg?.totalQuantity || 0,
    entryCount: agg?.entryCount || 0,
  };
};

const recordDamagedStock = async ({ stockId, quantity, reason = '' }, user) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const stock = await Stock.findById(stockId).session(session);
    if (!stock) throw new ApiError(404, 'Stock not found');
    if (stock.quantity < quantity) {
      throw new ApiError(400, 'Damaged quantity exceeds available stock');
    }

    stock.quantity -= quantity;
    await stock.save({ session });

    const [entry] = await DamagedStock.create(
      [
        {
          stockId: stock._id,
          chickenType: stock.chickenType,
          quantity,
          reason: reason.trim(),
          recordedBy: user._id,
        },
      ],
      { session }
    );

    await StockMovement.create(
      [
        {
          type: 'OUT',
          stockId: stock._id,
          chickenType: stock.chickenType,
          quantity,
          location: stock.location,
          reason: reason.trim() ? `Damaged stock: ${reason.trim()}` : 'Damaged stock',
          employeeId: user._id,
        },
      ],
      { session }
    );

    await session.commitTransaction();

    await logAction(user._id, user.name, 'RECORD_DAMAGED_STOCK', stock.chickenType, {
      quantity,
      reason,
    });

    return DamagedStock.findById(entry._id).populate('recordedBy', 'name');
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

module.exports = { listDamagedStock, getDamagedStockSummary, recordDamagedStock };
