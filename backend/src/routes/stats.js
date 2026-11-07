const express = require('express');
const Transaction = require('../models/Transaction');
const Wallet = require('../models/Wallet');
const User = require('../models/User');
const validate = require('../middleware/validate');
const s = require('../utils/schemas');
const { asyncHandler } = require('../utils/errors');
const { round2 } = require('../utils/balances');

const router = express.Router();

function dateMatch(from, to) {
  if (!from && !to) return {};
  const date = {};
  if (from) date.$gte = from;
  if (to) date.$lte = to;
  return { date };
}

function startOfMonth(d = new Date()) {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

// Totals for a period + all-time balance across wallets.
router.get(
  '/summary',
  validate(s.stats.range, 'query'),
  asyncHandler(async (req, res) => {
    const { from, to } = req.valid.query;

    const [periodRows, allRows, wallets, user, monthRows] = await Promise.all([
      Transaction.aggregate([
        { $match: { user: req.userId, ...dateMatch(from, to) } },
        { $group: { _id: '$type', total: { $sum: '$amount' }, count: { $sum: 1 } } },
      ]),
      Transaction.aggregate([
        { $match: { user: req.userId } },
        { $group: { _id: '$type', total: { $sum: '$amount' } } },
      ]),
      Wallet.find({ user: req.userId }).select('initialBalance'),
      User.findById(req.userId).select('monthlyBudget'),
      Transaction.aggregate([
        { $match: { user: req.userId, type: 'expense', date: { $gte: startOfMonth() } } },
        { $group: { _id: null, total: { $sum: '$amount' } } },
      ]),
    ]);

    const pick = (rows, t, f = 'total') => (rows.find((r) => r._id === t) || {})[f] || 0;
    const initial = wallets.reduce((sum, w) => sum + (w.initialBalance || 0), 0);
    const income = pick(periodRows, 'income');
    const expense = pick(periodRows, 'expense');

    res.json({
      income: round2(income),
      expense: round2(expense),
      net: round2(income - expense),
      count: pick(periodRows, 'income', 'count') + pick(periodRows, 'expense', 'count'),
      balance: round2(initial + pick(allRows, 'income') - pick(allRows, 'expense')),
      monthlyBudget: user ? user.monthlyBudget : 0,
      spentThisMonth: round2(monthRows[0] ? monthRows[0].total : 0),
    });
  })
);

// Breakdown of a period by category (where money came from / went to).
router.get(
  '/by-category',
  validate(s.stats.byCategory, 'query'),
  asyncHandler(async (req, res) => {
    const { type, from, to } = req.valid.query;
    const rows = await Transaction.aggregate([
      { $match: { user: req.userId, type, ...dateMatch(from, to) } },
      { $group: { _id: '$category', total: { $sum: '$amount' }, count: { $sum: 1 } } },
      { $sort: { total: -1 } },
      { $limit: 50 },
      { $lookup: { from: 'categories', localField: '_id', foreignField: '_id', as: 'cat' } },
      { $unwind: { path: '$cat', preserveNullAndEmptyArrays: true } },
    ]);
    const grand = rows.reduce((sum, r) => sum + r.total, 0);
    res.json({
      type,
      total: round2(grand),
      categories: rows.map((r) => ({
        id: r._id.toString(),
        name: r.cat ? r.cat.name : 'Deleted',
        icon: r.cat ? r.cat.icon : 'other',
        color: r.cat ? r.cat.color : '#64748B',
        total: round2(r.total),
        count: r.count,
        percent: grand > 0 ? Math.round((r.total / grand) * 1000) / 10 : 0,
      })),
    });
  })
);

// Income vs expense for each of the last N months (including the current one).
router.get(
  '/trend',
  validate(s.stats.trend, 'query'),
  asyncHandler(async (req, res) => {
    const { months } = req.valid.query;
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth() - (months - 1), 1);

    const rows = await Transaction.aggregate([
      { $match: { user: req.userId, date: { $gte: start } } },
      {
        $group: {
          _id: { y: { $year: '$date' }, m: { $month: '$date' }, t: '$type' },
          total: { $sum: '$amount' },
        },
      },
    ]);

    const result = [];
    for (let i = 0; i < months; i += 1) {
      const d = new Date(start.getFullYear(), start.getMonth() + i, 1);
      const y = d.getFullYear();
      const m = d.getMonth() + 1;
      const find = (t) => (rows.find((r) => r._id.y === y && r._id.m === m && r._id.t === t) || {}).total || 0;
      result.push({ year: y, month: m, income: round2(find('income')), expense: round2(find('expense')) });
    }
    res.json({ months: result });
  })
);

module.exports = router;
