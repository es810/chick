const mongoose = require('mongoose');
const Stock = require('../models/Stock');
const StockMovement = require('../models/StockMovement');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');

const addStock = async (data, employee) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { chickenType, quantity, averageWeight, pricePerKg, reason = 'Stock replenishment' } = data;

    let stock = await Stock.findOne({ chickenType }).session(session);

    if (stock) {
      stock.quantity += quantity;
      if (averageWeight) stock.averageWeight = averageWeight;
      if (pricePerKg) stock.pricePerKg = pricePerKg;
      await stock.save({ session });
    } else {
      [stock] = await Stock.create(
        [{ chickenType, quantity, averageWeight, pricePerKg }],
        { session }
      );
    }

    await StockMovement.create(
      [
        {
          type: 'IN',
          stockId: stock._id,
          chickenType: stock.chickenType,
          quantity,
          reason,
          employeeId: employee._id,
        },
      ],
      { session }
    );

    await session.commitTransaction();

    await logAction(employee._id, employee.name, 'STOCK_IN', chickenType, { quantity });

    return stock;
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

const getLowStockAlerts = async () => {
  const stocks = await Stock.find();
  return stocks.filter((s) => s.quantity <= s.lowStockThreshold);
};

const getMovements = async (filters = {}, page = 1, limit = 20) => {
  const query = {};
  if (filters.stockId) query.stockId = filters.stockId;
  if (filters.type) query.type = filters.type;

  const skip = (page - 1) * limit;
  const [movements, total] = await Promise.all([
    StockMovement.find(query)
      .populate('employeeId', 'name')
      .populate('stockId', 'chickenType')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
    StockMovement.countDocuments(query),
  ]);

  return { movements, total, page, pages: Math.ceil(total / limit) };
};

const deleteStockType = async (stockId, user) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const stock = await Stock.findById(stockId).session(session);
    if (!stock) throw new ApiError(404, 'Stock not found');

    if (stock.quantity > 0) {
      await StockMovement.create(
        [
          {
            type: 'OUT',
            stockId: stock._id,
            chickenType: stock.chickenType,
            quantity: stock.quantity,
            reason: 'Stock type deleted',
            employeeId: user._id,
          },
        ],
        { session }
      );
    }

    await Stock.findByIdAndDelete(stock._id, { session });
    await session.commitTransaction();

    await logAction(user._id, user.name, 'DELETE_STOCK', stock.chickenType, {
      quantityRemoved: stock.quantity,
    });

    return stock;
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

module.exports = { addStock, getLowStockAlerts, getMovements, deleteStockType };
