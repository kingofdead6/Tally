const express = require('express');
const bcrypt = require('bcryptjs');
const rateLimit = require('express-rate-limit');
const User = require('../models/User');
const Category = require('../models/Category');
const Wallet = require('../models/Wallet');
const validate = require('../middleware/validate');
const s = require('../utils/schemas');
const { asyncHandler, AppError } = require('../utils/errors');
const { DEFAULT_CATEGORIES, DEFAULT_WALLETS } = require('../utils/constants');
const { issueTokenPair, rotateRefreshToken, revokeRefreshToken } = require('../utils/tokens');

const router = express.Router();
const BCRYPT_ROUNDS = 12;

// A real hash to compare against when the email does not exist, so login
// takes the same time whether or not the account exists.
const DUMMY_HASH = bcrypt.hashSync('not-a-real-password-xyz', BCRYPT_ROUNDS);

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many attempts, try again in a few minutes' } },
});

// Per-account limiter on login, in addition to the per-IP one.
const loginAccountLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => `login:${String(req.body && req.body.email).toLowerCase().slice(0, 254)}`,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many attempts, try again in a few minutes' } },
});

const refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 60,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many requests' } },
});

async function seedDefaults(userId) {
  await Category.insertMany(DEFAULT_CATEGORIES.map((c) => ({ ...c, user: userId })));
  await Wallet.insertMany(DEFAULT_WALLETS.map((w) => ({ ...w, user: userId })));
}

router.post(
  '/register',
  authLimiter,
  validate(s.auth.register),
  asyncHandler(async (req, res) => {
    const { name, email, password } = req.body;
    const exists = await User.exists({ email });
    if (exists) throw new AppError(409, 'An account with this email already exists', 'EMAIL_TAKEN');

    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    const user = await User.create({ name, email, passwordHash });
    await seedDefaults(user._id);

    const tokens = await issueTokenPair(user._id);
    res.status(201).json({ user: user.toPublic(), ...tokens });
  })
);

router.post(
  '/login',
  authLimiter,
  validate(s.auth.login),
  loginAccountLimiter,
  asyncHandler(async (req, res) => {
    const { email, password } = req.body;
    const user = await User.findOne({ email }).select('+passwordHash');
    const ok = await bcrypt.compare(password, user ? user.passwordHash : DUMMY_HASH);
    if (!user || !ok) {
      console.warn(`[auth] failed login at ${new Date().toISOString()}`);
      throw new AppError(401, 'Incorrect email or password', 'INVALID_CREDENTIALS');
    }
    const tokens = await issueTokenPair(user._id);
    res.json({ user: user.toPublic(), ...tokens });
  })
);

router.post(
  '/refresh',
  refreshLimiter,
  validate(s.auth.refresh),
  asyncHandler(async (req, res) => {
    const rotated = await rotateRefreshToken(req.body.refreshToken);
    if (!rotated) throw new AppError(401, 'Session expired, please log in again', 'REFRESH_INVALID');
    const user = await User.findById(rotated.userId);
    if (!user) throw new AppError(401, 'Session expired, please log in again', 'REFRESH_INVALID');
    res.json({ user: user.toPublic(), ...rotated.tokens });
  })
);

router.post(
  '/logout',
  refreshLimiter,
  validate(s.auth.refresh),
  asyncHandler(async (req, res) => {
    await revokeRefreshToken(req.body.refreshToken);
    res.status(204).end();
  })
);

module.exports = router;
