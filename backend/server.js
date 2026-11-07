const env = require('./src/config/env');
const connectDB = require('./src/config/db');
const app = require('./src/app');

(async () => {
  try {
    await connectDB();
    app.listen(env.PORT, () => console.log(`Tally API listening on port ${env.PORT}`));
  } catch (err) {
    console.error('Failed to start server:', err.message);
    process.exit(1);
  }
})();
