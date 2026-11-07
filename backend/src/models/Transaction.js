const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    type: { type: String, enum: ['income', 'expense'], required: true },
    // Amount in DA, always positive; `type` decides the sign.
    amount: { type: Number, required: true, min: 0.01 },
    category: { type: mongoose.Schema.Types.ObjectId, ref: 'Category', required: true },
    wallet: { type: mongoose.Schema.Types.ObjectId, ref: 'Wallet', required: true },
    note: { type: String, trim: true, maxlength: 200, default: '' },
    date: { type: Date, required: true },
  },
  { timestamps: true }
);

transactionSchema.index({ user: 1, date: -1 });
transactionSchema.index({ user: 1, category: 1 });
transactionSchema.index({ user: 1, wallet: 1 });

transactionSchema.methods.toPublic = function toPublic() {
  const cat = this.category;
  const wal = this.wallet;
  return {
    id: this._id.toString(),
    type: this.type,
    amount: this.amount,
    note: this.note,
    date: this.date,
    category:
      cat && cat.name
        ? { id: cat._id.toString(), name: cat.name, icon: cat.icon, color: cat.color, type: cat.type }
        : { id: cat ? cat.toString() : null },
    wallet:
      wal && wal.name
        ? { id: wal._id.toString(), name: wal.name, icon: wal.icon, color: wal.color }
        : { id: wal ? wal.toString() : null },
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('Transaction', transactionSchema);
