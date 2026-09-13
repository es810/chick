const mongoose = require('mongoose');

const employeeLedgerSchema = new mongoose.Schema(
  {
    employeeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    type: { type: String, enum: ['expense', 'debt'], required: true },
    amount: { type: Number, required: true, min: 0 },
    description: { type: String, required: true, trim: true },
    supplierId: { type: mongoose.Schema.Types.ObjectId, ref: 'Supplier', default: null },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    clientMutationId: { type: String, default: null, sparse: true },
  },
  { timestamps: true }
);

employeeLedgerSchema.index({ employeeId: 1, createdAt: -1 });
employeeLedgerSchema.index({ type: 1, createdAt: -1 });
employeeLedgerSchema.index(
  { clientMutationId: 1 },
  { unique: true, partialFilterExpression: { clientMutationId: { $type: 'string' } } }
);

module.exports = mongoose.model('EmployeeLedger', employeeLedgerSchema);
