// Validates req[source] against a zod schema and replaces it with the parsed,
// typed result. Unknown body fields are rejected by `.strict()` schemas,
// which also blocks mass-assignment (e.g. sending `user` or `passwordHash`).
function validate(schema, source = 'body') {
  return (req, res, next) => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      const first = result.error.issues[0];
      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: first ? `${first.path.join('.') || 'input'}: ${first.message}` : 'Invalid input',
        },
      });
    }
    // Express 4 lets us overwrite req.query; keep parsed data in req.valid too.
    req.valid = req.valid || {};
    req.valid[source] = result.data;
    if (source === 'body') req.body = result.data;
    return next();
  };
}

module.exports = validate;
