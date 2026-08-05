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

  if ((delta.quantity || 0) > 0 || (delta.totalAmount || 0) > 0) {
    await StockMovement.create(
      [
        {
          type: 'IN',
          stockId: stock._id,
          chickenType,
          quantity: Math.max(0, delta.quantity || 0),
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
  const qtyDelta = Number(delta.quantity) || 0;
  const amountDelta = Number(delta.totalAmount) || 0;
  const grossDelta = Number(delta.grossWeight) || 0;
  const tareDelta = Number(delta.tareWeight) || 0;
  const netDelta = Number(delta.netWeight) || 0;

  if (!qtyDelta && !grossDelta && !tareDelta && !netDelta && !amountDelta) {
    return null;
  }

  // Quantity or value increase → purchase cost goes up (affects profit).
  if (qtyDelta > 0 || (qtyDelta === 0 && amountDelta > 0)) {
    return applyStockIncrement(session, chickenType, delta, user, reason);
  }

  const stock = await Stock.findOne({ chickenType }).session(session);
  if (!stock) return null;

  const requestedOut = Math.abs(qtyDelta);
  if (options.strict && requestedOut > stock.quantity) {
    throw new ApiError(400, `Insufficient stock for ${chickenType}`);
  }

  const outQty = options.strict
    ? requestedOut
    : Math.min(stock.quantity, requestedOut);
  stock.quantity = Math.max(0, stock.quantity + qtyDelta);
  stock.grossWeight = Math.max(0, stock.grossWeight + grossDelta);
  stock.tareWeight = Math.max(0, stock.tareWeight + tareDelta);
  stock.netWeight = Math.max(0, stock.netWeight + netDelta);
  stock.totalAmount = Math.max(0, stock.totalAmount + amountDelta);
  if (delta.pricePerKg != null) stock.pricePerKg = delta.pricePerKg;
  if (stock.quantity > 0) {
    stock.averageWeight = stock.netWeight / stock.quantity;
  } else {
    stock.averageWeight = 0;
  }
  await stock.save({ session });

  // Record purchase-cost reduction even when only the money changes (qty unchanged).
  const amountOut = amountDelta < 0 ? Math.abs(amountDelta) : Math.abs(delta.totalAmount || 0);
  if (outQty > 0 || amountDelta < 0) {
    await StockMovement.create(
      [
        {
          type: 'OUT',
          stockId: stock._id,
          chickenType,
          quantity: outQty,
          grossWeight: Math.abs(grossDelta),
          tareWeight: Math.abs(tareDelta),
          netWeight: Math.abs(netDelta),
          totalAmount: amountDelta < 0 ? Math.abs(amountDelta) : amountOut,
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
  if (quantity <= 0) {
    throw new ApiError(400, 'Invalid stock deduction quantity');
  }

  const beforeQty = stock.quantity || 0;
  const beforeNet = stock.netWeight || 0;
  const weight = Math.max(0, Number(actualNetWeight) || 0);
  const qtySurplus = Math.max(0, quantity - beforeQty);
  const deductQty = Math.min(quantity, beforeQty);

  // Book weight for birds that actually exist in stock (surplus count has no book weight).
  const bookNet =
    deductQty <= 0
      ? 0
      : deductQty === beforeQty
        ? beforeNet
        : beforeQty > 0
          ? (beforeNet * deductQty) / beforeQty
          : 0;
  const surplusKg = Math.max(0, Math.round((weight - bookNet) * 100) / 100);

  const stockId = stock._id;

  if (deductQty > 0) {
    const delta =
      deductQty === beforeQty
        ? {
            quantity: -beforeQty,
            grossWeight: -(stock.grossWeight || 0),
            tareWeight: -(stock.tareWeight || 0),
            netWeight: -beforeNet,
            totalAmount: -(stock.totalAmount || 0),
          }
        : {
            quantity: -deductQty,
            grossWeight: -((stock.grossWeight || 0) * deductQty) / beforeQty,
            tareWeight: -((stock.tareWeight || 0) * deductQty) / beforeQty,
            netWeight: -(weight > 0 ? Math.min(weight, beforeNet) : bookNet),
            totalAmount: -((stock.totalAmount || 0) * deductQty) / beforeQty,
          };

    await applyStockDelta(session, chickenType, delta, user, reason, {
      invoiceId,
      strict: true,
    });
  }

  if (qtySurplus > 0 || surplusKg > 0) {
    const { recordDistributionSurplus } = require('./damagedStockService');
    let surplusReason = 'زيادة التوزيع';
    if (qtySurplus > 0 && surplusKg > 0) surplusReason = 'زيادة عدد/وزن التوزيع';
    else if (qtySurplus > 0) surplusReason = 'زيادة عدد التوزيع';
    else surplusReason = 'زيادة وزن التوزيع';

    await recordDistributionSurplus({
      session,
      stockId,
      chickenType,
      quantity: qtySurplus,
      netWeight: surplusKg,
      invoiceId,
      user,
      reason: reason ? `${surplusReason} — ${reason}` : surplusReason,
    });
  }

  return { surplusKg, qtySurplus };
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
  return stocks.filter(
    (s) => (s.usableQuantity ?? s.quantity) <= s.lowStockThreshold
  );
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

    if ((stock.quantity || 0) > 0 || (stock.totalAmount || 0) > 0) {
      await StockMovement.create(
        [
          {
            type: 'OUT',
            stockId: stock._id,
            chickenType: stock.chickenType,
            quantity: stock.quantity || 0,
            grossWeight: stock.grossWeight || 0,
            tareWeight: stock.tareWeight || 0,
            netWeight: stock.netWeight || 0,
            totalAmount: stock.totalAmount || 0,
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

/**
 * Replace stock snapshot (edit form). Records IN/OUT so profit moves with the change.
 */
const updateStockSnapshot = async (stockId, data, user) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const existing = await Stock.findById(stockId).session(session);
    if (!existing) throw new ApiError(404, 'Stock not found');

    const before = {
      chickenType: existing.chickenType,
      quantity: existing.quantity || 0,
      location: existing.location || '',
      grossWeight: existing.grossWeight || 0,
      tareWeight: existing.tareWeight || 0,
      netWeight: existing.netWeight || 0,
      averageWeight: existing.averageWeight || 0,
      pricePerKg: existing.pricePerKg || 0,
      totalAmount: existing.totalAmount || 0,
    };

    const after = normalizeBatch({
      chickenType: data.chickenType ?? existing.chickenType,
      quantity: data.quantity ?? existing.quantity,
      location: data.location ?? existing.location,
      grossWeight: data.grossWeight ?? existing.grossWeight,
      tareWeight: data.tareWeight ?? existing.tareWeight,
      netWeight: data.netWeight ?? existing.netWeight,
      averageWeight: data.averageWeight ?? existing.averageWeight,
      pricePerKg: data.pricePerKg ?? existing.pricePerKg,
      totalAmount:
        data.totalAmount ??
        (data.pricePerKg != null && data.netWeight != null
          ? data.pricePerKg * data.netWeight
          : existing.totalAmount),
    });

    if (after.chickenType !== before.chickenType) {
      await applyStockDelta(
        session,
        before.chickenType,
        stockSnapshotDelta(
          {
            quantity: 0,
            grossWeight: 0,
            tareWeight: 0,
            netWeight: 0,
            totalAmount: 0,
          },
          before
        ),
        user,
        'Stock type changed — removed'
      );
      await applyStockIn(session, after, user, 'Stock type changed — added');
      await Stock.findByIdAndDelete(existing._id, { session });
    } else {
      const delta = stockSnapshotDelta(after, before);
      await applyStockDelta(
        session,
        before.chickenType,
        {
          ...delta,
          pricePerKg: after.pricePerKg,
          location: after.location,
          averageWeight: after.averageWeight,
        },
        user,
        'Stock updated'
      );
    }

    if (data.lowStockThreshold != null) {
      const stock = await Stock.findOne({ chickenType: after.chickenType }).session(session);
      if (stock) {
        stock.lowStockThreshold = data.lowStockThreshold;
        await stock.save({ session });
      }
    }

    await session.commitTransaction();

    await logAction(user._id, user.name, 'UPDATE_STOCK', after.chickenType);

    return Stock.findOne({ chickenType: after.chickenType });
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
  updateStockSnapshot,
  getLowStockAlerts,
  getMovements,
  deleteStockType,
};
