const SupplierPayment = require('../models/SupplierPayment');
const logger = require('./logger');

/**
 * Replace legacy sparse unique index on employeeLedgerId.
 * Explicit nulls under a sparse unique index caused "employeeLedgerId already exists"
 * when paying supplier debt via employee treasury.
 */
const migrateSupplierPaymentIndexes = async () => {
  try {
    const collection = SupplierPayment.collection;
    const indexes = await collection.indexes();

    for (const idx of indexes) {
      if (idx.name === '_id_') continue;
      const keys = Object.keys(idx.key || {});
      if (keys.length === 1 && keys[0] === 'employeeLedgerId') {
        const isLegacySparseUnique = idx.unique && idx.sparse;
        const isPartialObjectId =
          idx.unique &&
          idx.partialFilterExpression?.employeeLedgerId?.$type === 'objectId';
        if (isLegacySparseUnique || !isPartialObjectId) {
          await collection.dropIndex(idx.name);
          logger.info(`Dropped legacy SupplierPayment index: ${idx.name}`);
        }
      }
    }

    await SupplierPayment.syncIndexes();
  } catch (error) {
    logger.warn(`SupplierPayment index migration skipped: ${error.message}`);
  }
};

module.exports = { migrateSupplierPaymentIndexes };
