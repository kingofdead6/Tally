const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 60 },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true, maxlength: 254 },
    passwordHash: { type: String, required: true, select: false },
    // Monthly spending budget in DA (0 = no budget set)
    monthlyBudget: { type: Number, default: 0, min: 0 },
  },
  { timestamps: true }
);

// Explicit allowlist of what leaves the server.
userSchema.methods.toPublic = function toPublic() {
  return {
    id: this._id.toString(),
    name: this.name,
    email: this.email,
    monthlyBudget: this.monthlyBudget,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('User', userSchema);
