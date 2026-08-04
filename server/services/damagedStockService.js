const mongoose = require('mongoose');
const Stock = require('../models/Stock');
const DamagedStock = require('../models/DamagedStock');
const StockMovement = require('../models/StockMovement');
const Invoice = require('../models/Invoice');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');

const round2 = (n) => Math.round((Number(n) || 0) * 100) / 100;

const isOpenSurplus = (entry) =>
  entry.source === 'distribution_surplus' &&
  (entry.status == null || entry.status === 'open');

/**
 * Rebuild pending surplus on each stock from open distribution_surplus rows.
 * Safe to call repeatedly.
 */
const syncPendingSurplusFromOpenEntries = async () => {
  await Stock.updateMany(
    {},
    { $set: { pendingSurplusQuantity: 0, pendingSurplusNetWeight: 0 } }
  );

  const rows = await DamagedStock.aggregate([
    {
      $match: {
        source: 'distribution_surplus',
        $or: [{ status: 'open' }, { status: { $exists: false } }, { status: null }],
      },
    },
    {
      $group: {
        _id: '$stockId',
        qty: { $sum: '$quantity' },
        kg: { $sum: '$netWeight' },
      },
    },
  ]);

  for (const row of rows) {
    if (!row._id) continue;
    await Stock.findByIdAndUpdate(row._id, {
      pendingSurplusQuantity: Math.max(0, row.qty || 0),
      pendingSurplusNetWeight: Math.max(0, round2(row.kg || 0)),
    });
  }
};

const bumpPendingSurplus = async (session, stockId, qty, kg) => {
  const stock = await Stock.findById(stockId).session(session);
  if (!stock) return;
  stock.pendingSurplusQuantity = Math.max(
    0,
    (stock.pendingSurplusQuantity || 0) + (qty || 0)
  );
  stock.pendingSurplusNetWeight = Math.max(
    0,
    round2((stock.pendingSurplusNetWeight || 0) + (kg || 0))
  );
  await stock.save({ session });
};

const reducePendingSurplus = async (session, stockId, qty, kg) => {
  const stock = await Stock.findById(stockId).session(session);
  if (!stock) return;
  stock.pendingSurplusQuantity = Math.max(
    0,
    (stock.pendingSurplusQuantity || 0) - (qty || 0)
  );
  stock.pendingSurplusNetWeight = Math.max(
    0,
    round2((stock.pendingSurplusNetWeight || 0) - (kg || 0))
  );
  await stock.save({ session });
};

/**
 * Backfill surplus rows for invoices where sold kg/qty > book deducted.
 * Safe to call repeatedly (skips invoices that already have surplus entries).
 */
const reconcileDistributionSurplus = async () => {
  const invoices = await Invoice.find()
    .select('items invoiceNumber employeeId')
    .sort({ createdAt: -1 })
    .limit(2000)
    .lean();

  let created = false;

  for (const inv of invoices) {
    const existing = await DamagedStock.exists({
      invoiceId: inv._id,
      source: 'distribution_surplus',
    });
    if (existing) continue;

    for (const item of inv.items || []) {
      const mov = await StockMovement.findOne({
        invoiceId: inv._id,
        chickenType: item.chickenType,
        type: 'OUT',
      })
        .select('netWeight quantity')
        .lean();

      const bookNet = mov?.netWeight ?? 0;
      const bookQty = mov?.quantity ?? 0;
      const surplusKg = round2((item.weight || 0) - bookNet);
      const surplusQty = Math.max(0, (item.quantity || 0) - bookQty);
      if (surplusKg <= 0 && surplusQty <= 0) continue;

      const stock =
        (item.stockId && (await Stock.findById(item.stockId))) ||
        (await Stock.findOne({ chickenType: item.chickenType }));
      if (!stock || !inv.employeeId) continue;

      let reason = `زيادة التوزيع — Invoice #${inv.invoiceNumber}`;
      if (surplusQty > 0 && surplusKg > 0) {
        reason = `زيادة عدد/وزن التوزيع — Invoice #${inv.invoiceNumber}`;
      } else if (surplusQty > 0) {
        reason = `زيادة عدد التوزيع — Invoice #${inv.invoiceNumber}`;
      } else {
        reason = `زيادة وزن التوزيع — Invoice #${inv.invoiceNumber}`;
      }

      await DamagedStock.create({
        stockId: stock._id,
        chickenType: item.chickenType,
        quantity: surplusQty,
        netWeight: Math.max(0, surplusKg),
        reason,
        source: 'distribution_surplus',
        status: 'open',
        invoiceId: inv._id,
        recordedBy: inv.employeeId,
      });
      created = true;
    }
  }

  if (created) {
    await syncPendingSurplusFromOpenEntries();
  }
};

const listDamagedStock = async () => {
  await reconcileDistributionSurplus();
  // One-time style sync so legacy open surplus reduces "عندي مخزون"
  await syncPendingSurplusFromOpenEntries();
  return DamagedStock.find()
    .populate('recordedBy', 'name')
    .populate('stockId', 'chickenType location')
    .sort({ createdAt: -1 })
    .limit(500);
};

const getDamagedStockSummary = async () => {
  await reconcileDistributionSurplus();
  const [agg] = await DamagedStock.aggregate([
    {
      $group: {
        _id: null,
        totalQuantity: { $sum: '$quantity' },
        totalNetWeight: { $sum: '$netWeight' },
        entryCount: { $sum: 1 },
        openQuantity: {
          $sum: {
            $cond: [
              {
                $and: [
                  { $eq: ['$source', 'distribution_surplus'] },
                  { $ne: ['$status', 'written_off'] },
                ],
              },
              '$quantity',
              0,
            ],
          },
        },
        openNetWeight: {
          $sum: {
            $cond: [
              {
                $and: [
                  { $eq: ['$source', 'distribution_surplus'] },
                  { $ne: ['$status', 'written_off'] },
                ],
              },
              '$netWeight',
              0,
            ],
          },
        },
      },
    },
  ]);
  return {
    totalQuantity: agg?.totalQuantity || 0,
    totalNetWeight: round2(agg?.totalNetWeight || 0),
    entryCount: agg?.entryCount || 0,
    openQuantity: agg?.openQuantity || 0,
    openNetWeight: round2(agg?.openNetWeight || 0),
  };
};

/**
 * Auto entry when invoice count/weight exceeds book stock.
 * Raises pending surplus so usable "عندي مخزون" shrinks until هلك is confirmed.
 * Does not deduct book stock again.
 */
const recordDistributionSurplus = async ({
  session,
  stockId,
  chickenType,
  netWeight = 0,
  quantity = 0,
  invoiceId,
  user,
  reason,
}) => {
  const kg = round2(netWeight);
  const qty = Math.max(0, parseInt(quantity, 10) || 0);
  if (kg <= 0 && qty <= 0) return null;

  let defaultReason = 'زيادة التوزيع';
  if (qty > 0 && kg > 0) defaultReason = 'زيادة عدد/وزن التوزيع';
  else if (qty > 0) defaultReason = 'زيادة عدد التوزيع';
  else defaultReason = 'زيادة وزن التوزيع';

  const [entry] = await DamagedStock.create(
    [
      {
        stockId,
        chickenType,
        quantity: qty,
        netWeight: kg,
        reason: reason || defaultReason,
        source: 'distribution_surplus',
        status: 'open',
        invoiceId: invoiceId || null,
        recordedBy: user._id,
      },
    ],
    { session }
  );

  await bumpPendingSurplus(session, stockId, qty, kg);

  return entry;
};

const removeSurplusForInvoice = async (session, invoiceId) => {
  if (!invoiceId) return;
  const entries = await DamagedStock.find({
    invoiceId,
    source: 'distribution_surplus',
  }).session(session);

  for (const entry of entries) {
    if (isOpenSurplus(entry)) {
      await reducePendingSurplus(session, entry.stockId, entry.quantity, entry.netWeight);
    }
  }

  await DamagedStock.deleteMany({
    invoiceId,
    source: 'distribution_surplus',
  }).session(session);
};

/**
 * Confirm هلك of distribution surplus: clear pending so new loads are not reduced.
 * Does NOT deduct book stock again (oversell was never in book stock).
 */
const writeOffSurplus = async (entryId, user) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const entry = await DamagedStock.findById(entryId).session(session);
    if (!entry) throw new ApiError(404, 'Damaged stock entry not found');
    if (entry.source !== 'distribution_surplus') {
      throw new ApiError(400, 'Only distribution surplus can be written off this way');
    }
    if (entry.status === 'written_off') {
      await session.commitTransaction();
      return DamagedStock.findById(entry._id).populate('recordedBy', 'name');
    }

    await reducePendingSurplus(session, entry.stockId, entry.quantity, entry.netWeight);
    entry.status = 'written_off';
    await entry.save({ session });

    await session.commitTransaction();

    await logAction(user._id, user.name, 'WRITE_OFF_SURPLUS', entry.chickenType, {
      quantity: entry.quantity,
      netWeight: entry.netWeight,
      entryId: entry._id,
    });

    return DamagedStock.findById(entry._id).populate('recordedBy', 'name');
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

/**
 * Manual هلك of leftover birds/weight still on the books (e.g. died in yard).
 * Deducts real stock immediately; status written_off.
 */
const recordDamagedStock = async ({ stockId, quantity, netWeight, reason = '' }, user) => {
  const qty = Math.max(0, parseInt(quantity, 10) || 0);
  const kg = round2(netWeight);

  if (qty <= 0 && kg <= 0) {
    throw new ApiError(400, 'Quantity or weight is required');
  }

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const stock = await Stock.findById(stockId).session(session);
    if (!stock) throw new ApiError(404, 'Stock not found');

    if (qty > 0 && stock.quantity < qty) {
      throw new ApiError(400, 'Damaged quantity exceeds available stock');
    }

    const weightOut =
      kg > 0
        ? Math.min(kg, stock.netWeight || 0)
        : qty > 0 && stock.quantity > 0
          ? round2(((stock.netWeight || 0) * qty) / stock.quantity)
          : 0;

    if (qty > 0) {
      stock.quantity -= qty;
    }
    if (weightOut > 0) {
      const ratio =
        (stock.netWeight || 0) > 0 ? weightOut / stock.netWeight : 0;
      stock.netWeight = Math.max(0, round2((stock.netWeight || 0) - weightOut));
      stock.grossWeight = Math.max(0, round2((stock.grossWeight || 0) * (1 - ratio)));
      stock.tareWeight = Math.max(0, round2((stock.tareWeight || 0) * (1 - ratio)));
      stock.totalAmount = Math.max(0, round2((stock.totalAmount || 0) * (1 - ratio)));
    }
    if (stock.quantity > 0 && stock.netWeight > 0) {
      stock.averageWeight = stock.netWeight / stock.quantity;
    } else if (stock.quantity <= 0) {
      stock.quantity = 0;
      stock.averageWeight = 0;
      if (weightOut > 0 || qty > 0) {
        stock.grossWeight = 0;
        stock.tareWeight = 0;
        stock.netWeight = 0;
        stock.totalAmount = 0;
      }
    }
    await stock.save({ session });

    const [entry] = await DamagedStock.create(
      [
        {
          stockId: stock._id,
          chickenType: stock.chickenType,
          quantity: qty,
          netWeight: kg > 0 ? kg : weightOut,
          reason: reason.trim(),
          source: 'manual',
          status: 'written_off',
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
          quantity: qty || 0,
          netWeight: kg > 0 ? kg : weightOut,
          location: stock.location,
          reason: reason.trim() ? `Damaged stock: ${reason.trim()}` : 'Damaged stock',
          employeeId: user._id,
        },
      ],
      { session }
    );

    await session.commitTransaction();

    await logAction(user._id, user.name, 'RECORD_DAMAGED_STOCK', stock.chickenType, {
      quantity: qty,
      netWeight: kg > 0 ? kg : weightOut,
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

module.exports = {
  listDamagedStock,
  getDamagedStockSummary,
  recordDamagedStock,
  recordDistributionSurplus,
  removeSurplusForInvoice,
  reconcileDistributionSurplus,
  writeOffSurplus,
  syncPendingSurplusFromOpenEntries,
};
