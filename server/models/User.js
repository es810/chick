const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { DEFAULT_PERMISSIONS } = require('../utils/employeePermissions');

const permissionsSchema = new mongoose.Schema(
  {
    canEditInvoices: { type: Boolean, default: DEFAULT_PERMISSIONS.canEditInvoices },
    canViewOthersWork: { type: Boolean, default: DEFAULT_PERMISSIONS.canViewOthersWork },
    canTransfer: { type: Boolean, default: DEFAULT_PERMISSIONS.canTransfer },
    canAddExpense: { type: Boolean, default: DEFAULT_PERMISSIONS.canAddExpense },
    canPaySupplier: { type: Boolean, default: DEFAULT_PERMISSIONS.canPaySupplier },
  },
  { _id: false }
);

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    phone: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String, required: true, minlength: 6, select: false },
    role: {
      type: String,
      enum: ['admin', 'employee', 'client'],
      required: true,
      default: 'employee',
    },
    clientProfile: { type: mongoose.Schema.Types.ObjectId, ref: 'Client' },
    salary: { type: Number, default: 0, min: 0 },
    isActive: { type: Boolean, default: true },
    permissions: {
      type: permissionsSchema,
      default: () => ({ ...DEFAULT_PERMISSIONS }),
    },
  },
  { timestamps: true }
);

userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 12);
  next();
});

userSchema.methods.comparePassword = async function (candidate) {
  return bcrypt.compare(candidate, this.password);
};

userSchema.methods.toJSON = function () {
  const obj = this.toObject();
  delete obj.password;
  return obj;
};

module.exports = mongoose.model('User', userSchema);
