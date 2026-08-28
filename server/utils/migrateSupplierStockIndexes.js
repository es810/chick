const SupplierStock = require('../models/SupplierStock');
const logger = require('./logger');

/** Drop legacy unique index so each supplier load is stored separately. */
const migrateSupplierStockIndexes = async () => {
  try {
    const collection = SupplierStock.collection;
    const indexes = await collection.indexes();
    const legacyUnique = indexes.find(
      (idx) =>
        idx.unique &&
        idx.key?.supplierId === 1 &&
        idx.key?.chickenType === 1 &&
        Object.keys(idx.key).length === 2
    );

    if (legacyUnique) {
      await collection.dropIndex(legacyUnique.name);
      logger.info(`Dropped legacy SupplierStock index: ${legacyUnique.name}`);
    }

    await SupplierStock.syncIndexes();
  } catch (error) {
    logger.warn(`SupplierStock index migration skipped: ${error.message}`);
  }
};

module.exports = { migrateSupplierStockIndexes };
