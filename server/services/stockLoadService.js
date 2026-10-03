const mongoose = require('mongoose');
const Stock = require('../models/Stock');
const StockLoad = require('../models/StockLoad');
const DamagedStock = require('../models/DamagedStock');
const StockMovement = require('../models/StockMovement');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');

const round2 = (n) => Math.round((Number(n) || 0) * 100) / 100;

const OPEN_VARIANCE_SOURCES = [
  'distribution_surplus',
  'distribution_remainder',
  'load_deficit',
];

/**
 * Create a قيد تهليك row for a new STOCK_IN batch.
 */
const createStockLoad = async (session, { stock, quantity, netWeight, user }) => {
  const qty = Math.max(0, parseInt(quantity, 10) || 0);
  const kg = round2(netWeight);
  if (qty <= 0 && kg <= 0) return null;

  const [load] = await StockLoad.create(
    [
      {
        stockId: stock._id,
        chickenType: stock.chickenType,
        loadedQuantity: qty,
        loadedNetWeight: kg,
        remainingQuantity: qty,
        remainingNetWeight: kg,
        status: 'open',
        createdBy: user._id,
      },
    ],
    { session }
  );
  return load;
};

const listStockLoads = async (filters = {}) => {
  const query = {};
  if (filters.status) {
    const statuses = String(filters.status)
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    if (statuses.length === 1) query.status = statuses[0];
    else if (statuses.length > 1) query.status = { $in: statuses };
  } else {
    query.status = { $in: ['open', 'pending_writeoff'] };
  }
  if (filters.chickenType) query.chickenType = filters.chickenType;
  if (filters.stockId) query.stockId = filters.stockId;

  return StockLoad.find(query)
    .populate('createdBy', 'name')
    .populate('damagedStockId')
    .sort({ createdAt: 1 })
    .limit(500);
};

const settleDepletedLoad = async (session, load) => {
  if (!load || load.status !== 'open') return load;
  if ((load.remainingQuantity || 0) > 0) return load;
  // Still have leftover kg on this load — keep it open as usable remainder weight.
  if ((load.remainingNetWeight || 0) > 0.001) {
    load.remainingQuantity = 0;
    await load.save({ session });
    return load;
  }

  load.remainingQuantity = 0;
  load.remainingNetWeight = 0;

  const hasOpen = await DamagedStock.exists({
    stockLoadId: load._id,
    source: { $in: OPEN_VARIANCE_SOURCES },
    $or: [{ status: 'open' }, { status: { $exists: false } }, { status: null }],
  }).session(session);

  load.status = hasOpen ? 'pending_writeoff' : 'closed';
  await load.save({ session });
  return load;
};

/**
 * FIFO: reduce open loads for this chicken type by sold qty/kg.
 * Returns { lastTouched, allocations: [{ load, quantity, netWeight }] }.
 */
const consumeFromLoads = async (session, chickenType, quantity, netWeight) => {
  let qtyLeft = Math.max(0, parseInt(quantity, 10) || 0);
  let kgLeft = round2(netWeight);
  const empty = { lastTouched: null, allocations: [] };
  if (qtyLeft <= 0 && kgLeft <= 0) return empty;

  const loads = await StockLoad.find({ chickenType, status: 'open' })
    .sort({ createdAt: 1 })
    .session(session);

  let lastTouched = null;
  const allocations = [];

  for (const load of loads) {
    if (qtyLeft <= 0 && kgLeft <= 0) break;

    const takeQty = Math.min(qtyLeft, load.remainingQuantity || 0);
    let takeKg = 0;
    if (kgLeft > 0 && (load.remainingNetWeight || 0) > 0) {
      if (takeQty > 0 && (load.remainingQuantity || 0) > 0) {
        const proportional = round2(
          ((load.remainingNetWeight || 0) * takeQty) / load.remainingQuantity
        );
        takeKg = Math.min(kgLeft, proportional, load.remainingNetWeight || 0);
      } else {
        takeKg = Math.min(kgLeft, load.remainingNetWeight || 0);
      }
    } else if (takeQty > 0 && (load.remainingQuantity || 0) > 0) {
      takeKg = round2(
        ((load.remainingNetWeight || 0) * takeQty) / load.remainingQuantity
      );
    }

    if (takeQty <= 0 && takeKg <= 0) continue;

    load.remainingQuantity = Math.max(0, (load.remainingQuantity || 0) - takeQty);
    load.remainingNetWeight = Math.max(
      0,
      round2((load.remainingNetWeight || 0) - takeKg)
    );
    qtyLeft -= takeQty;
    kgLeft = round2(kgLeft - takeKg);
    lastTouched = load;
    allocations.push({ load, quantity: takeQty, netWeight: takeKg });

    await load.save({ session });
    if ((load.remainingQuantity || 0) <= 0 && (load.remainingNetWeight || 0) <= 0.001) {
      await settleDepletedLoad(session, load);
    }
  }

  return { lastTouched, allocations };
};

/**
 * Restore qty/kg onto a specific load when possible, else newest open/closed load.
 */
const restoreToLoads = async (session, chickenType, quantity, netWeight, stockLoadId = null) => {
  const qty = Math.max(0, parseInt(quantity, 10) || 0);
  const kg = round2(netWeight);
  if (qty <= 0 && kg <= 0) return;

  let load = null;
  if (stockLoadId) {
    load = await StockLoad.findById(stockLoadId).session(session);
  }

  if (!load) {
    load = await StockLoad.findOne({ chickenType, status: 'open' })
      .sort({ createdAt: -1 })
      .session(session);
  }

  if (!load) {
    load = await StockLoad.findOne({
      chickenType,
      status: { $in: ['pending_writeoff', 'closed'] },
    })
      .sort({ createdAt: -1 })
      .session(session);
  }

  if (!load) return;

  load.remainingQuantity = (load.remainingQuantity || 0) + qty;
  load.remainingNetWeight = round2((load.remainingNetWeight || 0) + kg);
  load.remainingQuantity = Math.min(
    load.remainingQuantity,
    load.loadedQuantity || load.remainingQuantity
  );
  load.remainingNetWeight = Math.min(
    load.remainingNetWeight,
    load.loadedNetWeight || load.remainingNetWeight
  );
  if (load.status !== 'open') {
    load.status = 'open';
    load.damagedStockId = null;
  }
  await load.save({ session });
};

/**
 * Link a DamagedStock variance row to a load and flip load to pending_writeoff if depleted.
 */
const attachVarianceToLoad = async (session, load, damagedEntry) => {
  if (!load || !damagedEntry) return;
  damagedEntry.stockLoadId = load._id;
  await damagedEntry.save({ session });

  if ((load.remainingQuantity || 0) <= 0 && load.status === 'open') {
    load.status = 'pending_writeoff';
    if (!load.damagedStockId) load.damagedStockId = damagedEntry._id;
    await load.save({ session });
  } else if (load.status === 'closed') {
    load.status = 'pending_writeoff';
    if (!load.damagedStockId) load.damagedStockId = damagedEntry._id;
    await load.save({ session });
  } else if (load.status === 'pending_writeoff' && !load.damagedStockId) {
    load.damagedStockId = damagedEntry._id;
    await load.save({ session });
  }
};

const closeLoadsForStock = async (session, stockId) => {
  await StockLoad.updateMany(
    { stockId, status: { $in: ['open', 'pending_writeoff'] } },
    { $set: { status: 'closed', remainingQuantity: 0, remainingNetWeight: 0 } },
    { session }
  );
};

/**
 * Manual إنهاء التوزيع: remaining is written off immediately (no تأكيد الهلاك).
 * Idempotent if already closed / pending_writeoff (legacy rows get closed).
 */
const finishStockLoad = async (loadId, user) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  const reducePending = async (stockId, qty, kg) => {
    const s = await Stock.findById(stockId).session(session);
    if (!s) return;
    s.pendingSurplusQuantity = Math.max(
      0,
      (s.pendingSurplusQuantity || 0) - (qty || 0)
    );
    s.pendingSurplusNetWeight = Math.max(
      0,
      round2((s.pendingSurplusNetWeight || 0) - (kg || 0))
    );
    await s.save({ session });
  };

  const writeOffOpenVariances = async (stock, loadDoc) => {
    const openVariances = await DamagedStock.find({
      $or: [
        { stockLoadId: loadDoc._id },
        {
          stockId: stock._id,
          chickenType: stock.chickenType,
          source: { $in: OPEN_VARIANCE_SOURCES },
          $or: [{ status: 'open' }, { status: { $exists: false } }, { status: null }],
        },
      ],
    }).session(session);

    let lastId = null;
    for (const entry of openVariances) {
      if (entry.status === 'written_off') continue;
      if (entry.source === 'distribution_surplus') {
        await reducePending(entry.stockId, entry.quantity, entry.netWeight);
      }
      entry.status = 'written_off';
      if (!entry.stockLoadId) entry.stockLoadId = loadDoc._id;
      await entry.save({ session });
      lastId = entry._id;
    }
    return lastId;
  };

  try {
    const load = await StockLoad.findById(loadId).session(session);
    if (!load) throw new ApiError(404, 'Stock load not found');

    // Already settled — close legacy pending_writeoff quietly.
    if (load.status === 'closed') {
      await session.commitTransaction();
      return StockLoad.findById(load._id)
        .populate('createdBy', 'name')
        .populate('damagedStockId');
    }

    if (load.status === 'pending_writeoff') {
      const stock = await Stock.findById(load.stockId).session(session);
      if (stock) {
        const lastId = await writeOffOpenVariances(stock, load);
        if (lastId) load.damagedStockId = lastId;
      }
      load.remainingQuantity = 0;
      load.remainingNetWeight = 0;
      load.status = 'closed';
      await load.save({ session });
      await session.commitTransaction();
      return StockLoad.findById(load._id)
        .populate('createdBy', 'name')
        .populate('damagedStockId');
    }

    if (load.status !== 'open') {
      throw new ApiError(400, 'لا يمكن إنهاء التوزيع إلا لقيد مفتوح');
    }

    const qty = Math.max(0, load.remainingQuantity || 0);
    const kg = round2(load.remainingNetWeight || 0);
    if (qty <= 0 && kg <= 0) {
      const stock = await Stock.findById(load.stockId).session(session);
      if (stock) await writeOffOpenVariances(stock, load);
      load.status = 'closed';
      await load.save({ session });
      await session.commitTransaction();
      return StockLoad.findById(load._id).populate('createdBy', 'name');
    }

    const stock = await Stock.findById(load.stockId).session(session);
    if (!stock) throw new ApiError(404, 'Stock not found');

    const usableQty = Math.max(
      0,
      (stock.quantity || 0) - (stock.pendingSurplusQuantity || 0)
    );
    const usableKg = Math.max(
      0,
      round2((stock.netWeight || 0) - (stock.pendingSurplusNetWeight || 0))
    );

    // Books already empty — sync load and write off any open variance immediately.
    if (usableQty <= 0 && usableKg <= 0.001) {
      load.remainingQuantity = 0;
      load.remainingNetWeight = 0;
      const lastId = await writeOffOpenVariances(stock, load);
      if (lastId) load.damagedStockId = lastId;
      load.status = 'closed';
      await load.save({ session });
      await session.commitTransaction();

      await logAction(user._id, user.name, 'FINISH_STOCK_LOAD', load.chickenType, {
        loadId: load._id,
        syncedEmptyBooks: true,
        writtenOffImmediately: true,
      });

      return StockLoad.findById(load._id)
        .populate('createdBy', 'name')
        .populate('damagedStockId');
    }

    const deductQty = Math.min(qty, usableQty);
    const weightOut =
      kg > 0
        ? Math.min(kg, stock.netWeight || 0, usableKg + 0.001)
        : deductQty > 0 && stock.quantity > 0
          ? round2(((stock.netWeight || 0) * deductQty) / stock.quantity)
          : 0;

    if (deductQty > 0) {
      stock.quantity -= deductQty;
    }
    if (weightOut > 0) {
      const ratio =
        (stock.netWeight || 0) > 0 ? weightOut / stock.netWeight : 0;
      stock.netWeight = Math.max(0, round2((stock.netWeight || 0) - weightOut));
      stock.grossWeight = Math.max(
        0,
        round2((stock.grossWeight || 0) * (1 - ratio))
      );
      stock.tareWeight = Math.max(
        0,
        round2((stock.tareWeight || 0) * (1 - ratio))
      );
      stock.totalAmount = Math.max(
        0,
        round2((stock.totalAmount || 0) * (1 - ratio))
      );
    }
    if (stock.quantity > 0 && stock.netWeight > 0) {
      stock.averageWeight = stock.netWeight / stock.quantity;
    } else if (stock.quantity <= 0) {
      stock.quantity = 0;
      stock.averageWeight = 0;
      if (weightOut > 0 || deductQty > 0) {
        stock.grossWeight = 0;
        stock.tareWeight = 0;
        stock.netWeight = 0;
        stock.totalAmount = 0;
      }
    }
    await stock.save({ session });

    const deficitQty = deductQty;
    const deficitKg = kg > 0 ? Math.min(kg, weightOut || kg) : weightOut;

    const [entry] = await DamagedStock.create(
      [
        {
          stockId: stock._id,
          chickenType: stock.chickenType,
          quantity: deficitQty,
          netWeight: deficitKg,
          reason: 'عجز الحمولة — إنهاء التوزيع',
          source: 'load_deficit',
          status: 'written_off',
          stockLoadId: load._id,
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
          quantity: deficitQty || 0,
          netWeight: deficitKg,
          location: stock.location,
          reason: 'Load deficit write-off (finish distribution)',
          employeeId: user._id,
          stockLoadId: load._id,
        },
      ],
      { session }
    );

    // Also settle any leftover open surplus/remainder for this type.
    await writeOffOpenVariances(stock, load);

    load.remainingQuantity = 0;
    load.remainingNetWeight = 0;
    load.status = 'closed';
    load.damagedStockId = entry._id;
    await load.save({ session });

    await session.commitTransaction();

    await logAction(user._id, user.name, 'FINISH_STOCK_LOAD', load.chickenType, {
      loadId: load._id,
      quantity: deficitQty,
      netWeight: deficitKg,
      writtenOffImmediately: true,
    });

    return StockLoad.findById(load._id)
      .populate('createdBy', 'name')
      .populate('damagedStockId');
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

/**
 * After confirming هلك for a load-linked variance, close the load if no open rows left.
 */
const closeLoadIfSettled = async (session, stockLoadId) => {
  if (!stockLoadId) return;
  const load = await StockLoad.findById(stockLoadId).session(session);
  if (!load || load.status === 'closed') return;

  const hasOpen = await DamagedStock.exists({
    stockLoadId,
    source: { $in: OPEN_VARIANCE_SOURCES },
    $or: [{ status: 'open' }, { status: { $exists: false } }, { status: null }],
  }).session(session);

  if (!hasOpen) {
    load.status = 'closed';
    await load.save({ session });
  }
};

/**
 * Account-statement style view of everything distributed from one stock load.
 */
const getLoadStatement = async (loadId) => {
  const Invoice = require('../models/Invoice');
  const load = await StockLoad.findById(loadId).populate('createdBy', 'name');
  if (!load) throw new ApiError(404, 'Stock load not found');

  const movements = await StockMovement.find({
    stockLoadId: load._id,
    type: 'OUT',
    invoiceId: { $ne: null },
  }).sort({ createdAt: 1 });

  const byInvoice = new Map();
  for (const mov of movements) {
    const key = mov.invoiceId.toString();
    const prev = byInvoice.get(key) || {
      invoiceId: key,
      quantity: 0,
      netWeight: 0,
      date: mov.createdAt,
    };
    prev.quantity += mov.quantity || 0;
    prev.netWeight = round2(prev.netWeight + (mov.netWeight || 0));
    if (mov.createdAt && (!prev.date || mov.createdAt < prev.date)) {
      prev.date = mov.createdAt;
    }
    byInvoice.set(key, prev);
  }

  const invoiceIds = [...byInvoice.keys()];
  const invoices = invoiceIds.length
    ? await Invoice.find({ _id: { $in: invoiceIds } }).populate('clientId', 'name phone')
    : [];
  const invoiceMap = new Map(invoices.map((inv) => [inv._id.toString(), inv]));

  const entries = [];
  for (const [invoiceId, alloc] of byInvoice) {
    const inv = invoiceMap.get(invoiceId);
    if (!inv) continue;

    // Amount for this load: proportional share of invoice total by net weight / birds.
    const item = (inv.items || []).find((i) => i.chickenType === load.chickenType);
    const itemTotal = item
      ? Number(item.total) ||
        (Number(item.unitPrice) || 0) * (Number(item.weight) || 0)
      : 0;
    const itemQty = item ? Number(item.quantity) || 0 : 0;
    const itemWeight = item ? Number(item.weight) || 0 : 0;
    let amount = 0;
    if (itemWeight > 0 && alloc.netWeight > 0) {
      amount = round2(itemTotal * (alloc.netWeight / itemWeight));
    } else if (itemQty > 0 && alloc.quantity > 0) {
      amount = round2(itemTotal * (alloc.quantity / itemQty));
    } else if (itemTotal > 0 && byInvoice.size === 1) {
      amount = round2(itemTotal);
    }

    entries.push({
      id: invoiceId,
      type: 'distribution',
      date: inv.createdAt || alloc.date,
      invoiceNumber: inv.invoiceNumber,
      description: `فاتورة توزيع #${inv.invoiceNumber}`,
      subtitle: inv.clientId?.name || '',
      clientId: inv.clientId?._id?.toString() || inv.clientId?.toString() || '',
      clientName: inv.clientId?.name || '',
      quantity: alloc.quantity,
      netWeight: alloc.netWeight,
      amount,
      paymentStatus: inv.paymentStatus || 'pending',
      debit: inv.paymentStatus === 'paid' ? 0 : amount,
      credit: 0,
    });
  }

  entries.sort((a, b) => new Date(a.date) - new Date(b.date));

  const variances = await DamagedStock.find({ stockLoadId: load._id })
    .sort({ createdAt: 1 })
    .lean();

  for (const v of variances) {
    entries.push({
      id: v._id.toString(),
      type: 'variance',
      date: v.createdAt,
      invoiceNumber: null,
      description: v.reason || v.source || 'هالك / فرق',
      subtitle: v.source || '',
      clientId: '',
      clientName: '',
      quantity: v.quantity || 0,
      netWeight: v.netWeight || 0,
      amount: 0,
      paymentStatus: v.status || 'open',
      debit: 0,
      credit: 0,
      source: v.source,
      status: v.status,
    });
  }

  entries.sort((a, b) => new Date(b.date) - new Date(a.date));

  const distEntries = entries.filter((e) => e.type === 'distribution');
  const totals = {
    distributedQuantity: distEntries.reduce((s, e) => s + (e.quantity || 0), 0),
    distributedNetWeight: round2(
      distEntries.reduce((s, e) => s + (e.netWeight || 0), 0)
    ),
    distributedAmount: round2(distEntries.reduce((s, e) => s + (e.amount || 0), 0)),
    unpaidAmount: round2(
      distEntries
        .filter((e) => e.paymentStatus !== 'paid')
        .reduce((s, e) => s + (e.amount || 0), 0)
    ),
    invoiceCount: distEntries.length,
  };

  return {
    load: {
      id: load._id.toString(),
      chickenType: load.chickenType,
      loadedQuantity: load.loadedQuantity,
      loadedNetWeight: load.loadedNetWeight,
      remainingQuantity: load.remainingQuantity,
      remainingNetWeight: load.remainingNetWeight,
      status: load.status,
      createdAt: load.createdAt,
      createdByName: load.createdBy?.name || '',
    },
    totals,
    entries,
  };
};

module.exports = {
  createStockLoad,
  listStockLoads,
  consumeFromLoads,
  restoreToLoads,
  attachVarianceToLoad,
  closeLoadsForStock,
  finishStockLoad,
  settleDepletedLoad,
  closeLoadIfSettled,
  getLoadStatement,
};
