const mongoose = require('mongoose');

// A category is either an income SOURCE (salary, freelance...) or an expense
// target (food, transport...). Icons are keys the app maps to built-in icons —
// no images are stored anywhere.
const categorySchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    name: { type: String, required: true, trim: true, maxlength: 40 },
    type: { type: String, enum: ['income', 'expense'], required: true },
    icon: { type: String, required: true, maxlength: 30 },
    color: { type: String, required: true, match: /^#[0-9A-Fa-f]{6}$/ },
  },
  { timestamps: true }
);

categorySchema.index({ user: 1, type: 1, name: 1 }, { unique: true });

categorySchema.methods.toPublic = function toPublic() {
  return {
    id: this._id.toString(),
    name: this.name,
    type: this.type,
    icon: this.icon,
    color: this.color,
  };
};

module.exports = mongoose.model('Category', categorySchema);
