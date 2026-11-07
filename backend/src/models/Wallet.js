const mongoose = require('mongoose');

// A place money is kept: cash, CCP / Edahabia, bank account, BaridiMob...
const walletSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    name: { type: String, required: true, trim: true, maxlength: 40 },
    icon: { type: String, required: true, maxlength: 30 },
    color: { type: String, required: true, match: /^#[0-9A-Fa-f]{6}$/ },
    initialBalance: { type: Number, default: 0 },
  },
  { timestamps: true }
);

walletSchema.index({ user: 1, name: 1 }, { unique: true });

walletSchema.methods.toPublic = function toPublic(balance) {
  return {
    id: this._id.toString(),
    name: this.name,
    icon: this.icon,
    color: this.color,
    initialBalance: this.initialBalance,
    balance: balance ?? this.initialBalance,
  };
};

module.exports = mongoose.model('Wallet', walletSchema);
