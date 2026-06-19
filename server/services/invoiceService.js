const mongoose = require('mongoose');
const Invoice = require('../models/Invoice');
const Stock = require('../models/Stock');
const StockMovement = require('../models/StockMovement');
const Client = require('../models/Client');
const ApiError = require('../utils/apiError');
const { logAction } = require('./auditService');

/** Tare weight (kg) = item count × TARE_KG_PER_UNIT */
const TARE_KG_PER_UNIT = 8;

const resolveTareWeight = (itemCount, inputTare) => {
  const count = Math.max(1, itemCount || 1);
  return count * TARE_KG_PER_UNIT;
};

const generateInvoiceNumber = async () => {
  const count = await Invoice.countDocuments();
  const date = new Date();
  const prefix = `INV-${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, '0')}`;
  return `${prefix}-${String(count + 1).padStart(5, '0')}`;
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
    } = data;

    const client = await Client.findById(clientId).session(session);
    if (!client) throw new ApiError(404, 'Client not found');

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

    const invoiceNumber = await generateInvoiceNumber();

    const itemCount =
      inputItemCount ?? processedItems.reduce((sum, i) => sum + i.quantity, 0);
    const tareWeight = resolveTareWeight(itemCount, inputTare);
    const grossWeight = inputGross ?? totalWeight + tareWeight;

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
          balanceAfter: balanceBefore,
          paymentStatus,
          notes,
        },
      ],
      { session }
    );

    const movementIds = await StockMovement.find({
      employeeId: employee._id,
      invoiceId: { $exists: false },
      createdAt: { $gte: new Date(Date.now() - 5000) },
    }).session(session);

    for (const mov of movementIds) {
      mov.invoiceId = invoice._id;
      mov.reason = `Invoice #${invoiceNumber}`;
      await mov.save({ session });
    }

    if (paymentStatus !== 'paid') {
      client.balance += totalPrice;
      await client.save({ session });
      invoice.balanceAfter = client.balance;
      await invoice.save({ session });
    } else {
      invoice.balanceAfter = balanceBefore;
      await invoice.save({ session });
    }

    await session.commitTransaction();

    await logAction(employee._id, employee.name, 'CREATE_INVOICE', invoiceNumber, {
      clientId,
      totalPrice,
    });

    return await Invoice.findById(invoice._id)
      .populate('clientId', 'name phone address')
      .populate('employeeId', 'name email');
  } catch (error) {
    await session.abortTransaction();
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
    const oldTotalPrice = invoice.totalPrice;
    const oldPaymentStatus = invoice.paymentStatus;

    if (oldPaymentStatus !== 'paid') {
      const oldClient = await Client.findById(oldClientId).session(session);
      if (oldClient) {
        oldClient.balance = Math.max(0, oldClient.balance - oldTotalPrice);
        await oldClient.save({ session });
      }
    }

    const newClientId = clientId || oldClientId;
    const client = await Client.findById(newClientId).session(session);
    if (!client) throw new ApiError(404, 'Client not found');

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
    invoice.balanceBefore = client.balance;

    if (newPaymentStatus !== 'paid') {
      client.balance += totalPrice;
      await client.save({ session });
      invoice.balanceAfter = client.balance;
    } else {
      invoice.balanceAfter = client.balance;
    }

    await invoice.save({ session });

    await session.commitTransaction();

    await logAction(user._id, user.name, 'UPDATE_INVOICE', invoice.invoiceNumber, {
      clientId: newClientId,
      totalPrice,
    });

    return await Invoice.findById(invoice._id)
      .populate('clientId', 'name phone address')
      .populate('employeeId', 'name email');
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

const updatePaymentStatus = async (invoiceId, paymentStatus, user) => {
  const invoice = await Invoice.findById(invoiceId).populate('clientId');
  if (!invoice) throw new ApiError(404, 'Invoice not found');

  const oldStatus = invoice.paymentStatus;
  invoice.paymentStatus = paymentStatus;

  if (paymentStatus === 'paid' && oldStatus !== 'paid') {
    const client = await Client.findById(invoice.clientId._id || invoice.clientId);
    client.balance = Math.max(0, client.balance - invoice.totalPrice);
    await client.save();
  }

  await invoice.save();

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

    if (invoice.paymentStatus !== 'paid') {
      const client = await Client.findById(invoice.clientId).session(session);
      if (client) {
        client.balance = Math.max(0, client.balance - invoice.totalPrice);
        await client.save({ session });
      }
    }

    await StockMovement.deleteMany({ invoiceId: invoice._id }).session(session);
    await Invoice.findByIdAndDelete(invoice._id).session(session);

    await session.commitTransaction();

    await logAction(user._id, user.name, 'DELETE_INVOICE', invoice.invoiceNumber, {
      totalPrice: invoice.totalPrice,
    });

    return { invoiceNumber: invoice.invoiceNumber };
  } catch (error) {
    await session.abortTransaction();
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
