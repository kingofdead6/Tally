const mongoose = require('mongoose');
const { verifyAccessToken } = require('../utils/tokens');

// Sets req.userId from a verified Bearer token. Every protected query then
// scopes by req.userId — never by an id the client sends.
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Authentication required' } });
  }
  try {
    const payload = verifyAccessToken(token);
    if (!mongoose.Types.ObjectId.isValid(payload.sub)) throw new Error('bad sub');
    req.userId = new mongoose.Types.ObjectId(payload.sub);
    return next();
  } catch (err) {
    const expired = err && err.name === 'TokenExpiredError';
    return res.status(401).json({
      error: {
        code: expired ? 'TOKEN_EXPIRED' : 'UNAUTHORIZED',
        message: expired ? 'Session expired' : 'Authentication required',
      },
    });
  }
}

module.exports = requireAuth;
