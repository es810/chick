const mongoose = require('mongoose');
const Supplier = require('../models/Supplier');
const SupplierStock = require('../models/SupplierStock');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');
const { applyStockIn, applyStockDelta, stockSnapshotDelta } = require('./stockService');

const ensureSupplier = async (supplierId) => {
  const supplier = await Supplier.findById(supplierId);
  if (!supplier) throw new ApiError(404, 'Supplier not found');
  return supplier;
};

const supplierReason = (supplier, action) => `${action}: ${supplier.name}`;

const stockLineTotal = (stock) => {
  if (!stock) return 0;
  if (stock.totalAmount > 0) return stock.totalAmount;
  return (stock.pricePerKg || 0) * (stock.netWeight || 0);
};

const adjustSupplierBalance = async (supplierId, delta, session) => {
  if (!delta) return;
  const supplier = await Supplier.findById(supplierId).session(session);
  if (!supplier) throw new ApiError(404, 'Supplier not found');
  supplier.balance = Math.max(0, (supplier.balance || 0) + delta);
  await supplier.save({ session });
};

const normalizeSupplierBatch = (data) => {
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

const addSupplierStock = async (supplierId, data, user) => {
  const supplier = await ensureSupplier(supplierId);
  const batch = normalizeSupplierBatch(data);
  const { chickenType, quantity } = batch;

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    let stock = await SupplierStock.findOne({ supplierId, chickenType }).session(session);

    if (stock) {
      stock.quantity += quantity;
      stock.location = batch.location || stock.location;
      stock.grossWeight = batch.grossWeight;
      stock.tareWeight = batch.tareWeight;
      stock.netWeight = batch.netWeight;
      stock.averageWeight = batch.averageWeight;
      stock.pricePerKg = batch.pricePerKg ?? stock.pricePerKg;
      stock.totalAmount = batch.totalAmount;
      await stock.save({ session });
    } else {
      [stock] = await SupplierStock.create(
        [
          {
            supplierId,
            ...batch,
          },
        ],
        { session }
      );
    }

    await applyStockIn(
      session,
      batch,
      user,
      supplierReason(supplier, 'Received from supplier')
    );

    await adjustSupplierBalance(supplierId, batch.totalAmount, session);

    await session.commitTransaction();
    await logAction(user._id, user.name, 'SUPPLIER_STOCK_IN', chickenType, { supplierId, quantity });

    return stock;
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

const updateSupplierStock = async (supplierId, stockId, updates, user) => {
  const supplier = await ensureSupplier(supplierId);

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const existing = await SupplierStock.findOne({ _id: stockId, supplierId }).session(session);
    if (!existing) throw new ApiError(404, 'Supplier stock not found');

    const before = existing.toObject();
    const beforeTotal = stockLineTotal(before);
    const merged = {
      chickenType: updates.chickenType ?? existing.chickenType,
      quantity: updates.quantity ?? existing.quantity,
      location: updates.location ?? existing.location,
      grossWeight: updates.grossWeight ?? existing.grossWeight,
      tareWeight: updates.tareWeight ?? existing.tareWeight,
      netWeight: updates.netWeight ?? existing.netWeight,
      averageWeight: updates.averageWeight ?? existing.averageWeight,
      pricePerKg: updates.pricePerKg ?? existing.pricePerKg,
      totalAmount:
        updates.totalAmount ??
        (updates.pricePerKg != null && updates.netWeight != null
          ? updates.pricePerKg * updates.netWeight
          : existing.totalAmount),
    };

    const after = normalizeSupplierBatch(merged);
    const delta = stockSnapshotDelta(after, before);

    Object.assign(existing, after);
    await existing.save({ session });

    await applyStockDelta(
      session,
      before.chickenType,
      delta,
      user,
      supplierReason(supplier, 'Supplier stock updated')
    );

    const afterTotal = stockLineTotal(existing);
    await adjustSupplierBalance(supplierId, afterTotal - beforeTotal, session);

    await session.commitTransaction();
    await logAction(user._id, user.name, 'UPDATE_SUPPLIER_STOCK', existing.chickenType, {
      supplierId,
    });

    return existing;
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

const removeSupplierStockFromMain = async (session, supplierStock, supplier, user) => {
  const delta = stockSnapshotDelta(
    {
      quantity: 0,
      grossWeight: 0,
      tareWeight: 0,
      netWeight: 0,
      totalAmount: 0,
    },
    supplierStock
  );
  await applyStockDelta(
    session,
    supplierStock.chickenType,
    delta,
    user,
    supplierReason(supplier, 'Supplier stock removed')
  );
};

const deleteSupplierStock = async (supplierId, stockId, user) => {
  const supplier = await ensureSupplier(supplierId);

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const stock = await SupplierStock.findOne({ _id: stockId, supplierId }).session(session);
    if (!stock) throw new ApiError(404, 'Supplier stock not found');

    const removedTotal = stockLineTotal(stock);

    await removeSupplierStockFromMain(session, stock.toObject(), supplier, user);
    await SupplierStock.findByIdAndDelete(stock._id, { session });
    await adjustSupplierBalance(supplierId, -removedTotal, session);

    await session.commitTransaction();
    await logAction(user._id, user.name, 'DELETE_SUPPLIER_STOCK', stock.chickenType, {
      supplierId,
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

const deleteAllForSupplier = async (supplierId, user) => {
  const supplier = await Supplier.findById(supplierId);
  if (!supplier) return;

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const items = await SupplierStock.find({ supplierId }).session(session);
    let removedTotal = 0;
    for (const item of items) {
      removedTotal += stockLineTotal(item);
      await removeSupplierStockFromMain(session, item.toObject(), supplier, user);
    }
    await SupplierStock.deleteMany({ supplierId }, { session });
    if (removedTotal > 0) {
      await adjustSupplierBalance(supplierId, -removedTotal, session);
    }
    await session.commitTransaction();
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

module.exports = {
  addSupplierStock,
  updateSupplierStock,
  deleteSupplierStock,
  deleteAllForSupplier,
  ensureSupplier,
};
