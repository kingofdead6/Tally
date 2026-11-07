const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const RefreshToken = require('../models/RefreshToken');

const ISSUER = 'tally-api';
const AUDIENCE = 'tally-app';

function signAccessToken(userId) {
  return jwt.sign({ sub: userId.toString() }, env.JWT_ACCESS_SECRET, {
    algorithm: 'HS256',
    expiresIn: env.JWT_ACCESS_EXPIRES,
    issuer: ISSUER,
    audience: AUDIENCE,
  });
}

function verifyAccessToken(token) {
  // Algorithm pinned; exp/iss/aud all checked.
  return jwt.verify(token, env.JWT_ACCESS_SECRET, {
    algorithms: ['HS256'],
    issuer: ISSUER,
    audience: AUDIENCE,
  });
}

const hashToken = (raw) => crypto.createHash('sha256').update(raw).digest('hex');

async function issueRefreshToken(userId) {
  const raw = crypto.randomBytes(48).toString('base64url');
  await RefreshToken.create({
    user: userId,
    tokenHash: hashToken(raw),
    expiresAt: new Date(Date.now() + env.REFRESH_TOKEN_DAYS * 24 * 60 * 60 * 1000),
  });
  return raw;
}

async function issueTokenPair(userId) {
  return {
    accessToken: signAccessToken(userId),
    refreshToken: await issueRefreshToken(userId),
  };
}

// Single-use rotation: the presented token is deleted atomically, so a
// replayed (stolen) refresh token cannot be used twice.
async function rotateRefreshToken(raw) {
  const doc = await RefreshToken.findOneAndDelete({
    tokenHash: hashToken(raw),
    expiresAt: { $gt: new Date() },
  });
  if (!doc) return null;
  return { userId: doc.user, tokens: await issueTokenPair(doc.user) };
}

async function revokeRefreshToken(raw) {
  await RefreshToken.deleteOne({ tokenHash: hashToken(raw) });
}

async function revokeAllForUser(userId) {
  await RefreshToken.deleteMany({ user: userId });
}

module.exports = {
  signAccessToken,
  verifyAccessToken,
  issueTokenPair,
  rotateRefreshToken,
  revokeRefreshToken,
  revokeAllForUser,
};
