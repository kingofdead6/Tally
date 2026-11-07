// Generic messages to the client, details only in server logs.
function notFound(req, res) {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Route not found' } });
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  if (err && err.expose && err.status) {
    return res.status(err.status).json({ error: { code: err.code, message: err.message } });
  }
  if (err && err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: { code: 'BAD_JSON', message: 'Malformed JSON body' } });
  }
  if (err && err.type === 'entity.too.large') {
    return res.status(413).json({ error: { code: 'TOO_LARGE', message: 'Request body too large' } });
  }
  if (err && err.code === 11000) {
    return res.status(409).json({ error: { code: 'DUPLICATE', message: 'That name is already used' } });
  }
  console.error(`[${new Date().toISOString()}] ${req.method} ${req.path}`, err);
  return res.status(500).json({ error: { code: 'SERVER_ERROR', message: 'Something went wrong' } });
}

module.exports = { notFound, errorHandler };
