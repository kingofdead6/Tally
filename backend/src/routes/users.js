const express = require('express');
const bcrypt = require('bcryptjs');
const rateLimit = require('express-rate-limit');
const User = require('../models/User');
const Category = require('../models/Category');
const Wallet = require('../models/Wallet');
const Transaction = require('../models/Transaction');
const RefreshToken = require('../models/RefreshToken');
const validate = require('../middleware/validate');
const s = require('../utils/schemas');
const { asyncHandler, AppError } = require('../utils/errors');
const { revokeAllForUser, issueTokenPair } = require('../utils/tokens');

const router = express.Router();

const sensitiveLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => `sensitive:${req.userId}`,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many attempts, try again later' } },
});

async function loadMe(userId, withHash = false) {
  const q = User.findById(userId);
  if (withHash) q.select('+passwordHash');
  const user = await q;
  if (!user) throw new AppError(401, 'Account not found', 'UNAUTHORIZED');
  return user;
}

router.get(
  '/me',
  asyncHandler(async (req, res) => {
    const user = await loadMe(req.userId);
    res.json({ user: user.toPublic() });
  })
);

router.patch(
  '/me',
  validate(s.user.update),
  asyncHandler(async (req, res) => {
    const user = await loadMe(req.userId);
    if (req.body.name !== undefined) user.name = req.body.name;
    if (req.body.monthlyBudget !== undefined) user.monthlyBudget = req.body.monthlyBudget;
    await user.save();
    res.json({ user: user.toPublic() });
  })
);

router.patch(
  '/me/password',
  sensitiveLimiter,
  validate(s.user.changePassword),
  asyncHandler(async (req, res) => {
    const user = await loadMe(req.userId, true);
    const ok = await bcrypt.compare(req.body.currentPassword, user.passwordHash);
    if (!ok) throw new AppError(400, 'Current password is incorrect', 'WRONG_PASSWORD');

    user.passwordHash = await bcrypt.hash(req.body.newPassword, 12);
    await user.save();
    // Sign out every other device, then give this device fresh tokens.
    await revokeAllForUser(user._id);
    const tokens = await issueTokenPair(user._id);
    res.json({ user: user.toPublic(), ...tokens });
  })
);

router.delete(
  '/me',
  sensitiveLimiter,
  validate(s.user.remove),
  asyncHandler(async (req, res) => {
    const user = await loadMe(req.userId, true);
    const ok = await bcrypt.compare(req.body.password, user.passwordHash);
    if (!ok) throw new AppError(400, 'Password is incorrect', 'WRONG_PASSWORD');

    await Promise.all([
      Transaction.deleteMany({ user: user._id }),
      Category.deleteMany({ user: user._id }),
      Wallet.deleteMany({ user: user._id }),
      RefreshToken.deleteMany({ user: user._id }),
    ]);
    await User.deleteOne({ _id: user._id });
    console.info(`[account] user deleted at ${new Date().toISOString()}`);
    res.status(204).end();
  })
);

module.exports = router;
