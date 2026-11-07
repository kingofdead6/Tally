const mongoose = require('mongoose');
const env = require('./env');

// NoSQL-injection protection comes from zod: every value that reaches a query
// is validated to a primitive (string/number/date/ObjectId), so a client can
// never smuggle in an operator object like {"$ne": null}.
mongoose.set('strictQuery', true);

async function connectDB() {
  await mongoose.connect(env.MONGO_URI);
  console.log('MongoDB connected');
}

module.exports = connectDB;
