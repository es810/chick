const mongoose = require('mongoose');
const Stock = require('../models/Stock');
const StockMovement = require('../models/StockMovement');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');

const normalizeBatch = (data) => {
  const {
    chickenType,
    quantity,
    location = '',
    grossWeight = 0,
    tareWeight = 0,
    netWeight = 0,
    averageWeight,
    pricePerKg,
    totalAmount,
  } = data;

  const avgWeight =
    averageWeight != null
      ? averageWeight
      : quantity > 0 && netWeight > 0
        ? netWeight / quantity
        : 0;
  const total =
    totalAmount != null ? totalAmount : (pricePerKg || 0) * (netWeight || 0);

  return {
    chickenType,
    quantity,
    location,
    grossWeight,
    tareWeight,
    netWeight,
    averageWeight: avgWeight,
    pricePerKg,
    totalAmount: total,
  };
};

const applyStockIn = async (session, data, user, reason) => {
  const batch = normalizeBatch(data);
  const {
    chickenType,
    quantity,
    location,
    grossWeight,
    tareWeight,
    netWeight,
    averageWeight,
    pricePerKg,
    totalAmount,
  } = batch;

  let stock = await Stock.findOne({ chickenType }).session(session);

  if (stock) {
    stock.quantity += quantity;
    stock.location = location || stock.location;
    stock.grossWeight = (stock.grossWeight || 0) + (grossWeight || 0);
    stock.tareWeight = (stock.tareWeight || 0) + (tareWeight || 0);
    stock.netWeight = (stock.netWeight || 0) + (netWeight || 0);
    stock.totalAmount = (stock.totalAmount || 0) + (totalAmount || 0);
    stock.pricePerKg = pricePerKg ?? stock.pricePerKg;
    stock.averageWeight =
      stock.quantity > 0 ? stock.netWeight / stock.quantity : averageWeight;
    await stock.save({ session });
  } else {
    [stock] = await Stock.create(
      [
        {
          location,
          chickenType,
          quantity,
          grossWeight,
          tareWeight,
          netWeight,
          averageWeight,
          pricePerKg,
          totalAmount,
        },
      ],
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
        location,
        grossWeight,
        tareWeight,
        netWeight,
        unitPrice: pricePerKg,
        totalAmount,
        reason,
        employeeId: user._id,
      },
    ],
    { session }
  );

  return stock;
};

const stockSnapshotDelta = (after, before = {}) => ({
  quantity: (after.quantity || 0) - (before.quantity || 0),
  grossWeight: (after.grossWeight || 0) - (before.grossWeight || 0),
  tareWeight: (after.tareWeight || 0) - (before.tareWeight || 0),
  netWeight: (after.netWeight || 0) - (before.netWeight || 0),
  totalAmount: (after.totalAmount || 0) - (before.totalAmount || 0),
  averageWeight: after.averageWeight,
  pricePerKg: after.pricePerKg,
  location: after.location,
});

const applyStockIncrement = async (session, chickenType, delta, user, reason) => {
  let stock = await Stock.findOne({ chickenType }).session(session);

  if (!stock) {
    [stock] = await Stock.create(
      [
        {
          chickenType,
          quantity: Math.max(0, delta.quantity || 0),
          location: delta.location || '',
          grossWeight: Math.max(0, delta.grossWeight || 0),
          tareWeight: Math.max(0, delta.tareWeight || 0),
          netWeight: Math.max(0, delta.netWeight || 0),
          averageWeight: delta.averageWeight || 0,
          pricePerKg: delta.pricePerKg || 0,
          totalAmount: Math.max(0, delta.totalAmount || 0),
        },
      ],
      { session }
    );
  } else {
    stock.quantity += delta.quantity || 0;
    stock.grossWeight = Math.max(0, stock.grossWeight + (delta.grossWeight || 0));
    stock.tareWeight = Math.max(0, stock.tareWeight + (delta.tareWeight || 0));
    stock.netWeight = Math.max(0, stock.netWeight + (delta.netWeight || 0));
    stock.totalAmount = Math.max(0, stock.totalAmount + (delta.totalAmount || 0));
    if (delta.pricePerKg != null) stock.pricePerKg = delta.pricePerKg;
    if (delta.location) stock.location = delta.location;
    if (stock.quantity > 0) {
      stock.averageWeight = stock.netWeight / stock.quantity;
    }
    await stock.save({ session });
  }

  if ((delta.quantity || 0) > 0) {
    await StockMovement.create(
      [
        {
          type: 'IN',
          stockId: stock._id,
          chickenType,
          quantity: delta.quantity,
          grossWeight: Math.max(0, delta.grossWeight || 0),
          tareWeight: Math.max(0, delta.tareWeight || 0),
          netWeight: Math.max(0, delta.netWeight || 0),
          unitPrice: delta.pricePerKg,
          totalAmount: Math.max(0, delta.totalAmount || 0),
          reason,
          employeeId: user._id,
        },
      ],
      { session }
    );
  }

  return stock;
};

const proportionalOutDelta = (stock, outQty) => {
  if (outQty <= 0) {
    throw new ApiError(400, 'Invalid stock deduction quantity');
  }
  if (stock.quantity < outQty) {
    throw new ApiError(400, `Insufficient stock for ${stock.chickenType}`);
  }
  if (outQty === stock.quantity) {
    return {
      quantity: -stock.quantity,
      grossWeight: -stock.grossWeight,
      tareWeight: -stock.tareWeight,
      netWeight: -stock.netWeight,
      totalAmount: -stock.totalAmount,
    };
  }
  const ratio = outQty / stock.quantity;
  return {
    quantity: -outQty,
    grossWeight: -(stock.grossWeight * ratio),
    tareWeight: -(stock.tareWeight * ratio),
    netWeight: -(stock.netWeight * ratio),
    totalAmount: -(stock.totalAmount * ratio),
  };
};

const applyStockDelta = async (session, chickenType, delta, user, reason, options = {}) => {
  if (
    !delta.quantity &&
    !delta.grossWeight &&
    !delta.tareWeight &&
    !delta.netWeight &&
    !delta.totalAmount
  ) {
    return null;
  }

  if ((delta.quantity || 0) > 0) {
    return applyStockIncrement(session, chickenType, delta, user, reason);
  }

  const stock = await Stock.findOne({ chickenType }).session(session);
  if (!stock) return null;

  const requestedOut = Math.abs(delta.quantity || 0);
  if (options.strict && requestedOut > stock.quantity) {
    throw new ApiError(400, `Insufficient stock for ${chickenType}`);
  }

  const outQty = options.strict
    ? requestedOut
    : Math.min(stock.quantity, requestedOut);
  stock.quantity = Math.max(0, stock.quantity + (delta.quantity || 0));
  stock.grossWeight = Math.max(0, stock.grossWeight + (delta.grossWeight || 0));
  stock.tareWeight = Math.max(0, stock.tareWeight + (delta.tareWeight || 0));
  stock.netWeight = Math.max(0, stock.netWeight + (delta.netWeight || 0));
  stock.totalAmount = Math.max(0, stock.totalAmount + (delta.totalAmount || 0));
  if (delta.pricePerKg != null) stock.pricePerKg = delta.pricePerKg;
  if (stock.quantity > 0) {
    stock.averageWeight = stock.netWeight / stock.quantity;
  } else {
    stock.averageWeight = 0;
  }
  await stock.save({ session });

  if (outQty > 0) {
    await StockMovement.create(
      [
        {
          type: 'OUT',
          stockId: stock._id,
          chickenType,
          quantity: outQty,
          grossWeight: Math.abs(delta.grossWeight || 0),
          tareWeight: Math.abs(delta.tareWeight || 0),
          netWeight: Math.abs(delta.netWeight || 0),
          totalAmount: Math.abs(delta.totalAmount || 0),
          reason,
          employeeId: user._id,
          invoiceId: options.invoiceId,
        },
      ],
      { session }
    );
  }

  return stock;
};

const deductStockForInvoice = async (
  session,
  chickenType,
  quantity,
  user,
  reason,
  invoiceId,
  actualNetWeight = null
) => {
  const stock = await Stock.findOne({ chickenType }).session(session);
  if (!stock) throw new ApiError(404, `Stock not found for type: ${chickenType}`);
  if (stock.quantity < quantity) {
    throw new ApiError(400, `Insufficient stock for ${chickenType}`);
  }

  const beforeQty = stock.quantity;
  const beforeNet = stock.netWeight || 0;
  const weight = Math.max(0, Number(actualNetWeight) || 0);
  const bookNet =
    quantity === beforeQty
      ? beforeNet
      : beforeQty > 0
        ? (beforeNet * quantity) / beforeQty
        : 0;
  const surplusKg = Math.max(0, Math.round((weight - bookNet) * 100) / 100);

  const delta =
    quantity === beforeQty
      ? {
          quantity: -beforeQty,
          grossWeight: -(stock.grossWeight || 0),
          tareWeight: -(stock.tareWeight || 0),
          netWeight: -beforeNet,
          totalAmount: -(stock.totalAmount || 0),
        }
      : {
          quantity: -quantity,
          grossWeight: -((stock.grossWeight || 0) * quantity) / beforeQty,
          tareWeight: -((stock.tareWeight || 0) * quantity) / beforeQty,
          // Deduct actual sold weight (floored at 0 inside applyStockDelta)
          netWeight: -(weight > 0 ? weight : bookNet),
          totalAmount: -((stock.totalAmount || 0) * quantity) / beforeQty,
        };

  const stockId = stock._id;
  await applyStockDelta(session, chickenType, delta, user, reason, {
    invoiceId,
    strict: true,
  });

  if (surplusKg > 0) {
    const { recordDistributionSurplus } = require('./damagedStockService');
    await recordDistributionSurplus({
      session,
      stockId,
      chickenType,
      netWeight: surplusKg,
      invoiceId,
      user,
      reason: reason ? `زيادة وزن التوزيع — ${reason}` : 'زيادة وزن التوزيع',
    });
  }

  return { surplusKg };
};

const restoreStockForInvoice = async (session, invoiceId, user, reason) => {
  const movements = await StockMovement.find({ invoiceId, type: 'OUT' }).session(session);
  for (const mov of movements) {
    await applyStockIncrement(session, mov.chickenType, {
      quantity: mov.quantity,
      grossWeight: mov.grossWeight || 0,
      tareWeight: mov.tareWeight || 0,
      netWeight: mov.netWeight || 0,
      totalAmount: mov.totalAmount || 0,
    }, user, reason);
  }
  await StockMovement.deleteMany({ invoiceId }).session(session);

  const { removeSurplusForInvoice } = require('./damagedStockService');
  await removeSurplusForInvoice(session, invoiceId);
};

const addStock = async (data, employee) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const stock = await applyStockIn(
      session,
      data,
      employee,
      data.reason || 'Stock replenishment'
    );
    await session.commitTransaction();
    await logAction(employee._id, employee.name, 'STOCK_IN', data.chickenType, {
      quantity: data.quantity,
    });
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

module.exports = {
  addStock,
  applyStockIn,
  applyStockIncrement,
  applyStockDelta,
  proportionalOutDelta,
  deductStockForInvoice,
  restoreStockForInvoice,
  stockSnapshotDelta,
  getLowStockAlerts,
  getMovements,
  deleteStockType,
};
