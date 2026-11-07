const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const env = require('./config/env');
const requireAuth = require('./middleware/auth');
const { notFound, errorHandler } = require('./middleware/error');

const app = express();

if (env.TRUST_PROXY) app.set('trust proxy', env.TRUST_PROXY);
app.disable('x-powered-by');

app.use(helmet());
// Mobile apps send no Origin header and are unaffected by CORS. Browsers are
// only allowed from the explicit allowlist in CORS_ORIGINS.
app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin || env.corsOrigins.includes(origin)) return cb(null, true);
      return cb(null, false);
    },
  })
);
app.use(express.json({ limit: '20kb' }));

app.use(
  '/api',
  rateLimit({
    windowMs: 60 * 1000,
    limit: 300,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    message: { error: { code: 'RATE_LIMITED', message: 'Too many requests, slow down' } },
  })
);

app.get('/api/health', (req, res) => res.json({ ok: true }));

app.use('/api/auth', require('./routes/auth'));
app.use('/api/users', requireAuth, require('./routes/users'));
app.use('/api/categories', requireAuth, require('./routes/categories'));
app.use('/api/wallets', requireAuth, require('./routes/wallets'));
app.use('/api/transactions', requireAuth, require('./routes/transactions'));
app.use('/api/stats', requireAuth, require('./routes/stats'));

app.use(notFound);
app.use(errorHandler);

module.exports = app;
