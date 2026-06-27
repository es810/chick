const mongoose = require('mongoose');

const salaryAdvanceSchema = new mongoose.Schema(
  {
    employeeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    advanceDate: { type: Date, required: true },
    amount: { type: Number, required: true, min: 0.01 },
    notes: { type: String, default: '', trim: true },
    treasuryMovementId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'TreasuryMovement',
      required: true,
    },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

salaryAdvanceSchema.index({ employeeId: 1, advanceDate: -1 });
salaryAdvanceSchema.index({ advanceDate: 1 });

module.exports = mongoose.model('SalaryAdvance', salaryAdvanceSchema);
