/**
 * Receipt snapshot lines — never use live client.balance as «مستحق بعد».
 *
 * Distribution: after = prior debt + meal (or prior if paid).
 * Collection: after = before − paid − discount.
 */
const receiptBalanceAfterInvoice = ({
  balanceBefore = 0,
  totalPrice = 0,
  paymentStatus = 'pending',
} = {}) => {
  const before = Math.max(0, Number(balanceBefore) || 0);
  const meal = Math.max(0, Number(totalPrice) || 0);
  if (paymentStatus === 'paid') return before;
  return before + meal;
};

const receiptBalanceAfterCollection = ({
  balanceBefore = 0,
  amountPaid = 0,
  amountDeducted = 0,
} = {}) => {
  const before = Math.max(0, Number(balanceBefore) || 0);
  const paid = Math.max(0, Number(amountPaid) || 0);
  const deducted = Math.max(0, Number(amountDeducted) || 0);
  return Math.max(0, before - paid - deducted);
};

const applyInvoiceReceiptBalances = (invoice) => {
  invoice.balanceBefore = Math.max(0, Number(invoice.balanceBefore) || 0);
  invoice.balanceAfter = receiptBalanceAfterInvoice({
    balanceBefore: invoice.balanceBefore,
    totalPrice: invoice.totalPrice,
    paymentStatus: invoice.paymentStatus,
  });
  return invoice;
};

const applyCollectionReceiptBalances = (invoice) => {
  invoice.balanceBefore = Math.max(0, Number(invoice.balanceBefore) || 0);
  invoice.balanceAfter = receiptBalanceAfterCollection({
    balanceBefore: invoice.balanceBefore,
    amountPaid: invoice.amountPaid,
    amountDeducted: invoice.amountDeducted,
  });
  return invoice;
};

module.exports = {
  receiptBalanceAfterInvoice,
  receiptBalanceAfterCollection,
  applyInvoiceReceiptBalances,
  applyCollectionReceiptBalances,
};
