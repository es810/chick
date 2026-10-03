const mongoose = require('mongoose');

const employeeTreasuryTransferSchema = new mongoose.Schema(
  {
    fromEmployeeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    toEmployeeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    amount: { type: Number, required: true, min: 0.01 },
    notes: { type: String, default: '', trim: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    clientMutationId: { type: String, default: null, sparse: true },
  },
  { timestamps: true }
);

employeeTreasuryTransferSchema.index({ fromEmployeeId: 1, createdAt: -1 });
employeeTreasuryTransferSchema.index({ toEmployeeId: 1, createdAt: -1 });
employeeTreasuryTransferSchema.index(
  { clientMutationId: 1 },
  { unique: true, partialFilterExpression: { clientMutationId: { $type: 'string' } } }
);

module.exports = mongoose.model('EmployeeTreasuryTransfer', employeeTreasuryTransferSchema);
