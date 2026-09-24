/**
 * Per-employee feature flags. Admins ignore these checks.
 * Defaults match historical “full employee” behavior except view-others / transfer.
 */
const DEFAULT_PERMISSIONS = {
  canEditInvoices: true,
  canViewOthersWork: false,
  canTransfer: false,
  canAddExpense: true,
  canPaySupplier: true,
};

const normalizePermissions = (raw) => {
  const src = raw && typeof raw === 'object' ? raw : {};
  return {
    canEditInvoices:
      src.canEditInvoices !== undefined
        ? Boolean(src.canEditInvoices)
        : DEFAULT_PERMISSIONS.canEditInvoices,
    canViewOthersWork:
      src.canViewOthersWork !== undefined
        ? Boolean(src.canViewOthersWork)
        : DEFAULT_PERMISSIONS.canViewOthersWork,
    canTransfer:
      src.canTransfer !== undefined
        ? Boolean(src.canTransfer)
        : DEFAULT_PERMISSIONS.canTransfer,
    canAddExpense:
      src.canAddExpense !== undefined
        ? Boolean(src.canAddExpense)
        : DEFAULT_PERMISSIONS.canAddExpense,
    canPaySupplier:
      src.canPaySupplier !== undefined
        ? Boolean(src.canPaySupplier)
        : DEFAULT_PERMISSIONS.canPaySupplier,
  };
};

const getPermissions = (user) => {
  if (!user || user.role === 'admin') {
    return {
      canEditInvoices: true,
      canViewOthersWork: true,
      canTransfer: true,
      canAddExpense: true,
      canPaySupplier: true,
    };
  }
  return normalizePermissions(user.permissions);
};

const hasPermission = (user, key) => Boolean(getPermissions(user)[key]);

module.exports = {
  DEFAULT_PERMISSIONS,
  normalizePermissions,
  getPermissions,
  hasPermission,
};
