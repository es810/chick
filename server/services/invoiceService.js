const mongoose = require('mongoose');
const Invoice = require('../models/Invoice');
const Stock = require('../models/Stock');
const Client = require('../models/Client');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');
const { deductStockForInvoice, restoreStockForInvoice } = require('./stockService');
const {
  ensureClientOpeningBalance,
  syncClientBalanceFromLedger,
} = require('./clientBalanceService');
const { receiptBalanceAfterInvoice } = require('../utils/receiptBalances');

/** Tare weight (kg) = item count × TARE_KG_PER_UNIT */
const TARE_KG_PER_UNIT = 8;

const resolveTareWeight = (itemCount, inputTare) => {
  const count = Math.max(1, itemCount || 1);
  return count * TARE_KG_PER_UNIT;
};

/** Next INV-YYYYMM-##### from the highest existing number (safe after deletes). */
const generateInvoiceNumber = async () => {
  const date = new Date();
  const prefix = `INV-${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, '0')}`;
  const latest = await Invoice.findOne({ invoiceNumber: new RegExp(`^${prefix}-`) })
    .sort({ invoiceNumber: -1 })
    .select('invoiceNumber')
    .lean();

  let seq = 1;
  if (latest?.invoiceNumber) {
    const last = parseInt(String(latest.invoiceNumber).split('-').pop(), 10);
    if (!Number.isNaN(last) && last >= 0) seq = last + 1;
  }
  return `${prefix}-${String(seq).padStart(5, '0')}`;
};

const safeAbort = async (session) => {
  try {
    if (session.inTransaction()) await session.abortTransaction();
  } catch (_) {
    /* already committed/aborted */
  }
};

const createInvoice = async (data, employee) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const {
      clientId,
      items,
      paymentStatus = 'pending',
      notes = '',
      grossWeight: inputGross,
      tareWeight: inputTare = 0,
      itemCount: inputItemCount,
      clientMutationId,
    } = data;

    if (clientMutationId) {
      const existing = await Invoice.findOne({ clientMutationId }).session(session);
      if (existing) {
        await session.commitTransaction();
        return Invoice.findById(existing._id)
          .populate('clientId', 'name phone address whatsappGroupLink')
          .populate('employeeId', 'name email');
      }
    }

    const client = await Client.findById(clientId).session(session);
    if (!client) throw new ApiError(404, 'Client not found');

    await ensureClientOpeningBalance(client, session);
    const balanceBefore = client.balance;

    const processedItems = [];
    let totalWeight = 0;
    let totalPrice = 0;

    for (const item of items) {
      const stock = await Stock.findOne({ chickenType: item.chickenType }).session(session);
      if (!stock) {
        throw new ApiError(404, `Stock not found for type: ${item.chickenType}`);
      }

      const weight = item.weight || stock.averageWeight * item.quantity;
      const unitPrice = item.unitPrice || stock.pricePerKg;
      const total = weight * unitPrice;

      processedItems.push({
        chickenType: stock.chickenType,
        stockId: stock._id,
        quantity: item.quantity,
        weight,
        unitPrice,
        total,
      });

      totalWeight += weight;
      totalPrice += total;
    }

    const itemCount =
      inputItemCount ?? processedItems.reduce((sum, i) => sum + i.quantity, 0);
    const tareWeight = resolveTareWeight(itemCount, inputTare);
    const grossWeight = inputGross ?? totalWeight + tareWeight;

    const invoiceNumber = await generateInvoiceNumber();

    const [invoice] = await Invoice.create(
      [
        {
          invoiceNumber,
          clientId,
          employeeId: employee._id,
          items: processedItems,
          itemCount,
          grossWeight,
          tareWeight,
          totalWeight,
          totalPrice,
          balanceBefore,
          balanceAfter: receiptBalanceAfterInvoice({
            balanceBefore,
            totalPrice,
            paymentStatus,
          }),
          paymentStatus,
          notes,
          ...(clientMutationId ? { clientMutationId } : {}),
        },
      ],
      { session }
    );

    const invoiceReason = `Invoice #${invoice.invoiceNumber}`;
    for (const item of processedItems) {
      await deductStockForInvoice(
        session,
        item.chickenType,
        item.quantity,
        employee,
        invoiceReason,
        invoice._id,
        item.weight
      );
    }

    // Rebuild from ledger movements while retaining the separately stored opening debt.
    await syncClientBalanceFromLedger(clientId, session);
    await invoice.save({ session });

    await session.commitTransaction();

    await logAction(employee._id, employee.name, 'CREATE_INVOICE', invoice.invoiceNumber, {
      clientId,
      totalPrice,
    });

    return await Invoice.findById(invoice._id)
      .populate('clientId', 'name phone address whatsappGroupLink')
      .populate('employeeId', 'name email');
  } catch (error) {
    await safeAbort(session);
    throw error;
  } finally {
    session.endSession();
  }
};

const updateInvoiceFull = async (invoiceId, data, user) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const invoice = await Invoice.findById(invoiceId).session(session);
    if (!invoice) throw new ApiError(404, 'Invoice not found');

    const {
      clientId,
      items,
      paymentStatus,
      notes,
      grossWeight: inputGross,
      tareWeight: inputTare,
      itemCount: inputItemCount,
    } = data;
    if (!items?.length) throw new ApiError(400, 'At least one item is required');

    const oldClientId = invoice.clientId.toString();
    const oldPaymentStatus = invoice.paymentStatus;
    const previousTotalPrice = invoice.totalPrice || 0;
    const invoiceReason = `Invoice #${invoice.invoiceNumber}`;

    await restoreStockForInvoice(
      session,
      invoice._id,
      user,
      `${invoiceReason} updated - stock restored`
    );

    const newClientId = clientId || oldClientId;
    const client = await Client.findById(newClientId).session(session);
    if (!client) throw new ApiError(404, 'Client not found');
    await ensureClientOpeningBalance(client, session);
    if (String(oldClientId) !== String(newClientId)) {
      const oldClient = await Client.findById(oldClientId).session(session);
      if (oldClient) await ensureClientOpeningBalance(oldClient, session);
    }

    const processedItems = [];
    let totalWeight = 0;
    let totalPrice = 0;

    for (const item of items) {
      const stock = await Stock.findOne({ chickenType: item.chickenType }).session(session);
      if (!stock) {
        throw new ApiError(404, `Stock not found for type: ${item.chickenType}`);
      }

      const weight = item.weight || stock.averageWeight * item.quantity;
      const unitPrice = item.unitPrice || stock.pricePerKg;
      const total = weight * unitPrice;

      processedItems.push({
        chickenType: stock.chickenType,
        stockId: stock._id,
        quantity: item.quantity,
        weight,
        unitPrice,
        total,
      });

      totalWeight += weight;
      totalPrice += total;
    }

    const newPaymentStatus = paymentStatus ?? oldPaymentStatus;

    const itemCount =
      inputItemCount ?? processedItems.reduce((sum, i) => sum + i.quantity, 0);
    const tareWeight = resolveTareWeight(itemCount, inputTare);
    const grossWeight = inputGross ?? totalWeight + tareWeight;
    invoice.clientId = newClientId;
    invoice.items = processedItems;
    invoice.itemCount = itemCount;
    invoice.grossWeight = grossWeight;
    invoice.tareWeight = tareWeight;
    invoice.totalWeight = totalWeight;
    invoice.totalPrice = totalPrice;
    invoice.paymentStatus = newPaymentStatus;
    if (notes !== undefined) invoice.notes = notes;

    // Prior debt must exclude this invoice. client.balance still includes the old
    // unpaid total, so subtracting it prevents «مستحق قبل» from doubling the meal.
    const sameClient = String(oldClientId) === String(newClientId);
    const previousContribution =
      sameClient && oldPaymentStatus !== 'paid' ? previousTotalPrice : 0;
    invoice.balanceBefore = Math.max(0, (client.balance || 0) - previousContribution);
    invoice.balanceAfter = receiptBalanceAfterInvoice({
      balanceBefore: invoice.balanceBefore,
      totalPrice,
      paymentStatus: newPaymentStatus,
    });
    await invoice.save({ session });

    await syncClientBalanceFromLedger(newClientId, session);
    if (!sameClient) {
      await syncClientBalanceFromLedger(oldClientId, session);
    }

    for (const item of processedItems) {
      await deductStockForInvoice(
        session,
        item.chickenType,
        item.quantity,
        user,
        invoiceReason,
        invoice._id,
        item.weight
      );
    }

    await session.commitTransaction();

    await logAction(user._id, user.name, 'UPDATE_INVOICE', invoice.invoiceNumber, {
      clientId: newClientId,
      totalPrice,
    });

    return await Invoice.findById(invoice._id)
      .populate('clientId', 'name phone address whatsappGroupLink')
      .populate('employeeId', 'name email');
  } catch (error) {
    await safeAbort(session);
    throw error;
  } finally {
    session.endSession();
  }
};

const updatePaymentStatus = async (invoiceId, paymentStatus, user) => {
  const invoice = await Invoice.findById(invoiceId).populate('clientId');
  if (!invoice) throw new ApiError(404, 'Invoice not found');

  const clientId = invoice.clientId._id || invoice.clientId;
  await ensureClientOpeningBalance(clientId);
  const oldStatus = invoice.paymentStatus;
  invoice.paymentStatus = paymentStatus;
  invoice.balanceAfter = receiptBalanceAfterInvoice({
    balanceBefore: invoice.balanceBefore,
    totalPrice: invoice.totalPrice,
    paymentStatus,
  });
  await invoice.save();

  await syncClientBalanceFromLedger(clientId);

  await logAction(user._id, user.name, 'UPDATE_PAYMENT', invoice.invoiceNumber, {
    from: oldStatus,
    to: paymentStatus,
  });

  return invoice;
};

const deleteInvoice = async (invoiceId, user) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const invoice = await Invoice.findById(invoiceId).session(session);
    if (!invoice) throw new ApiError(404, 'Invoice not found');

    const clientId = invoice.clientId;
    const client = await Client.findById(clientId).session(session);
    if (client) await ensureClientOpeningBalance(client, session);

    await restoreStockForInvoice(
      session,
      invoice._id,
      user,
      `Invoice #${invoice.invoiceNumber} deleted - stock restored`
    );
    await Invoice.findByIdAndDelete(invoice._id).session(session);
    await syncClientBalanceFromLedger(clientId, session);

    await session.commitTransaction();

    await logAction(user._id, user.name, 'DELETE_INVOICE', invoice.invoiceNumber, {
      totalPrice: invoice.totalPrice,
    });

    return { invoiceNumber: invoice.invoiceNumber };
  } catch (error) {
    await safeAbort(session);
    throw error;
  } finally {
    session.endSession();
  }
};

module.exports = {
  createInvoice,
  updateInvoiceFull,
  updatePaymentStatus,
  deleteInvoice,
  generateInvoiceNumber,
};
