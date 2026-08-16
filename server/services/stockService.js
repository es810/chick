const mongoose = require('mongoose');
const Stock = require('../models/Stock');
const StockMovement = require('../models/StockMovement');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');

const normalizeBatch = (data) => {
  const chickenType = String(data.chickenType || '').trim();
  const quantity = Math.max(0, parseInt(data.quantity, 10) || 0);
  const location = data.location != null ? String(data.location).trim() : '';
  const grossWeight = Math.max(0, Number(data.grossWeight) || 0);
  const tareWeight = Math.max(0, Number(data.tareWeight) || 0);
  let netWeight = Math.max(0, Number(data.netWeight) || 0);
  const pricePerKg = Math.max(0, Number(data.pricePerKg) || 0);

  if (grossWeight > 0 || tareWeight > 0) {
    const fromScale = Math.round((grossWeight - tareWeight) * 100) / 100;
    if (fromScale >= 0) {
      netWeight = fromScale;
    }
  }

  const avgWeight =
    data.averageWeight != null && Number(data.averageWeight) > 0
      ? Number(data.averageWeight)
      : quantity > 0 && netWeight > 0
        ? netWeight / quantity
        : 0;

  // Always price × net — never trust a client-provided totalAmount.
  const total = Math.round(pricePerKg * netWeight * 100) / 100;

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
    // Weighted average so price × net stays equal to accumulated money.
    stock.pricePerKg =
      stock.netWeight > 0
        ? Math.round((stock.totalAmount / stock.netWeight) * 10000) / 10000
        : pricePerKg ?? stock.pricePerKg;
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

  // Each STOCK_IN batch gets its own قيد تهليك session.
  if (quantity > 0 || netWeight > 0) {
    const { createStockLoad } = require('./stockLoadService');
    await createStockLoad(session, {
      stock,
      quantity,
      netWeight,
      user,
    });
  }

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
    stock.pricePerKg =
      stock.netWeight > 0
        ? Math.round((stock.totalAmount / stock.netWeight) * 10000) / 10000
        : delta.pricePerKg != null
          ? delta.pricePerKg
          : stock.pricePerKg;
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

  // Keep قيد التهليك in sync when stock is reduced outside invoice FIFO
  // (e.g. edit/delete snapshot). Invoice path sets skipLoadConsume.
  if (
    !options.skipLoadConsume &&
    (outQty > 0 || netDelta < 0)
  ) {
    const { consumeFromLoads } = require('./stockLoadService');
    await consumeFromLoads(
      session,
      chickenType,
      outQty,
      Math.abs(Math.min(0, netDelta))
    );
  }

  // Record purchase-cost reduction even when only the money/weight changes (qty unchanged).
  const amountOut = amountDelta < 0 ? Math.abs(amountDelta) : Math.abs(delta.totalAmount || 0);
  if (outQty > 0 || amountDelta < 0 || netDelta < 0) {
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

  // Proportional book weight for the birds being removed (money / leftover math).
  const bookNet =
    deductQty <= 0
      ? 0
      : deductQty === beforeQty
        ? beforeNet
        : beforeQty > 0
          ? (beforeNet * deductQty) / beforeQty
          : 0;
  // Weight oversell = sold kg above ALL remaining book kg (not proportional share).
  // Selling heavier birds first is normal and must not create false surplus.
  const surplusKg = Math.max(0, Math.round((weight - beforeNet) * 100) / 100);

  const stockId = stock._id;

  if (deductQty > 0) {
    const soldKg =
      weight > 0 ? Math.min(weight, beforeNet) : bookNet > 0 ? bookNet : 0;
    // All cages out but birds were lighter → keep leftover kg on books (usable stock).
    const leftoverKg =
      deductQty === beforeQty && beforeNet > 0 && soldKg < beforeNet - 0.0001
        ? Math.round((beforeNet - soldKg) * 100) / 100
        : 0;

    let delta;
    if (deductQty === beforeQty && leftoverKg > 0) {
      const soldRatio = beforeNet > 0 ? soldKg / beforeNet : 1;
      delta = {
        quantity: -beforeQty,
        grossWeight: -((stock.grossWeight || 0) * soldRatio),
        tareWeight: -((stock.tareWeight || 0) * soldRatio),
        netWeight: -soldKg,
        totalAmount: -((stock.totalAmount || 0) * soldRatio),
      };
    } else if (deductQty === beforeQty) {
      delta = {
        quantity: -beforeQty,
        grossWeight: -(stock.grossWeight || 0),
        tareWeight: -(stock.tareWeight || 0),
        netWeight: -beforeNet,
        totalAmount: -(stock.totalAmount || 0),
      };
    } else {
      delta = {
        quantity: -deductQty,
        grossWeight: -((stock.grossWeight || 0) * deductQty) / beforeQty,
        tareWeight: -((stock.tareWeight || 0) * deductQty) / beforeQty,
        netWeight: -(weight > 0 ? Math.min(weight, beforeNet) : bookNet),
        totalAmount: -((stock.totalAmount || 0) * deductQty) / beforeQty,
      };
    }

    await applyStockDelta(session, chickenType, delta, user, reason, {
      invoiceId,
      strict: true,
      skipLoadConsume: true,
    });

    // FIFO: reduce قيد التهليك by birds/kg actually taken from books (not leftover).
    const { consumeFromLoads, attachVarianceToLoad } = require('./stockLoadService');
    const touchedLoad = await consumeFromLoads(
      session,
      chickenType,
      deductQty,
      soldKg
    );

    if (qtySurplus > 0 || surplusKg > 0) {
      const { recordDistributionSurplus } = require('./damagedStockService');
      const bookLabel = Math.round(beforeNet * 100) / 100;
      const soldLabel = Math.round(weight * 100) / 100;
      let surplusReason = 'زيادة التوزيع';
      if (qtySurplus > 0 && surplusKg > 0) {
        surplusReason =
          `زيادة عدد/وزن التوزيع (العدد +${qtySurplus}، الوزن الموزّع ${soldLabel} والمخزون ${bookLabel})`;
      } else if (qtySurplus > 0) {
        surplusReason = `زيادة عدد التوزيع (+${qtySurplus})`;
      } else {
        surplusReason =
          `زيادة وزن التوزيع (وزّعت ${soldLabel} كجم والمخزون كان ${bookLabel} كجم)`;
      }

      const surplusEntry = await recordDistributionSurplus({
        session,
        stockId,
        chickenType,
        quantity: qtySurplus,
        netWeight: surplusKg,
        invoiceId,
        user,
        reason: reason ? `${surplusReason} — ${reason}` : surplusReason,
        stockLoadId: touchedLoad?._id || null,
      });
      if (surplusEntry && touchedLoad) {
        await attachVarianceToLoad(session, touchedLoad, surplusEntry);
      }
    }

    return { surplusKg, qtySurplus, leftoverKg };
  }

  // Birds already at 0 but leftover kg still on books — allow weight-only OUT.
  if (beforeQty <= 0 && beforeNet > 0 && weight > 0) {
    const takeKg = Math.min(weight, beforeNet);
    const soldRatio = beforeNet > 0 ? takeKg / beforeNet : 1;
    await applyStockDelta(
      session,
      chickenType,
      {
        quantity: 0,
        grossWeight: -((stock.grossWeight || 0) * soldRatio),
        tareWeight: -((stock.tareWeight || 0) * soldRatio),
        netWeight: -takeKg,
        totalAmount: -((stock.totalAmount || 0) * soldRatio),
      },
      user,
      reason,
      { invoiceId, strict: false, skipLoadConsume: true }
    );
    const { consumeFromLoads, attachVarianceToLoad } = require('./stockLoadService');
    const touchedLoad = await consumeFromLoads(session, chickenType, 0, takeKg);
    const weightSurplus = Math.max(0, Math.round((weight - beforeNet) * 100) / 100);
    if (weightSurplus > 0 || qtySurplus > 0) {
      const { recordDistributionSurplus } = require('./damagedStockService');
      const surplusEntry = await recordDistributionSurplus({
        session,
        stockId,
        chickenType,
        quantity: qtySurplus,
        netWeight: weightSurplus,
        invoiceId,
        user,
        reason: reason || 'زيادة التوزيع',
        stockLoadId: touchedLoad?._id || null,
      });
      if (surplusEntry && touchedLoad) {
        await attachVarianceToLoad(session, touchedLoad, surplusEntry);
      }
    }
    return { surplusKg: weightSurplus, qtySurplus, leftoverKg: 0 };
  }

  // Oversell with no book stock left to deduct — still record surplus.
  const { attachVarianceToLoad } = require('./stockLoadService');
  const StockLoad = require('../models/StockLoad');
  const touchedLoad =
    (await StockLoad.findOne({
      chickenType,
      status: { $in: ['open', 'pending_writeoff', 'closed'] },
    })
      .sort({ createdAt: -1 })
      .session(session)) || null;

  if (qtySurplus > 0 || surplusKg > 0) {
    const { recordDistributionSurplus } = require('./damagedStockService');
    const bookLabel = Math.round(beforeNet * 100) / 100;
    const soldLabel = Math.round(weight * 100) / 100;
    let surplusReason = 'زيادة التوزيع';
    if (qtySurplus > 0 && surplusKg > 0) {
      surplusReason =
        `زيادة عدد/وزن التوزيع (العدد +${qtySurplus}، الوزن الموزّع ${soldLabel} والمخزون ${bookLabel})`;
    } else if (qtySurplus > 0) {
      surplusReason = `زيادة عدد التوزيع (+${qtySurplus})`;
    } else {
      surplusReason =
        `زيادة وزن التوزيع (وزّعت ${soldLabel} كجم والمخزون كان ${bookLabel} كجم)`;
    }

    const surplusEntry = await recordDistributionSurplus({
      session,
      stockId,
      chickenType,
      quantity: qtySurplus,
      netWeight: surplusKg,
      invoiceId,
      user,
      reason: reason ? `${surplusReason} — ${reason}` : surplusReason,
      stockLoadId: touchedLoad?._id || null,
    });
    if (surplusEntry && touchedLoad) {
      await attachVarianceToLoad(session, touchedLoad, surplusEntry);
    }
  }

  return { surplusKg, qtySurplus };
};

const restoreStockForInvoice = async (session, invoiceId, user, reason) => {
  const movements = await StockMovement.find({ invoiceId, type: 'OUT' }).session(session);
  const { restoreToLoads } = require('./stockLoadService');
  for (const mov of movements) {
    await applyStockIncrement(session, mov.chickenType, {
      quantity: mov.quantity,
      grossWeight: mov.grossWeight || 0,
      tareWeight: mov.tareWeight || 0,
      netWeight: mov.netWeight || 0,
      totalAmount: mov.totalAmount || 0,
    }, user, reason);
    await restoreToLoads(
      session,
      mov.chickenType,
      mov.quantity || 0,
      mov.netWeight || 0
    );
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

    const { closeLoadsForStock } = require('./stockLoadService');
    await closeLoadsForStock(session, stock._id);

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
      const { closeLoadsForStock } = require('./stockLoadService');
      await closeLoadsForStock(session, existing._id);
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
