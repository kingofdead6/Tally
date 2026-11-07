const Transaction = require('../models/Transaction');

// Returns Map<walletIdString, net> of (income - expense) per wallet for one user.
async function netByWallet(userId) {
  const rows = await Transaction.aggregate([
    { $match: { user: userId } },
    {
      $group: {
        _id: '$wallet',
        net: { $sum: { $cond: [{ $eq: ['$type', 'income'] }, '$amount', { $multiply: ['$amount', -1] }] } },
      },
    },
  ]);
  return new Map(rows.map((r) => [r._id.toString(), r.net]));
}

const round2 = (v) => Math.round((v || 0) * 100) / 100;

module.exports = { netByWallet, round2 };
