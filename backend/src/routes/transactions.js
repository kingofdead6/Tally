const express = require('express');
const Transaction = require('../models/Transaction');
const Category = require('../models/Category');
const Wallet = require('../models/Wallet');
const validate = require('../middleware/validate');
const s = require('../utils/schemas');
const { asyncHandler, AppError } = require('../utils/errors');

const router = express.Router();
const POPULATE = [
  { path: 'category', select: 'name icon color type' },
  { path: 'wallet', select: 'name icon color' },
];

const escapeRegex = (str) => str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Both the category and the wallet must belong to the caller, and the
// category's type must match the transaction's type.
async function assertRefs(userId, { type, category, wallet }) {
  if (category) {
    const cat = await Category.findOne({ _id: category, user: userId }).select('type');
    if (!cat) throw new AppError(400, 'Category not found', 'BAD_CATEGORY');
    if (type && cat.type !== type) {
      throw new AppError(400, `Pick ${type === 'income' ? 'an income source' : 'an expense category'}`, 'TYPE_MISMATCH');
    }
  }
  if (wallet) {
    const ok = await Wallet.exists({ _id: wallet, user: userId });
    if (!ok) throw new AppError(400, 'Wallet not found', 'BAD_WALLET');
  }
}

router.get(
  '/',
  validate(s.transaction.list, 'query'),
  asyncHandler(async (req, res) => {
    const { type, category, wallet, from, to, q, page, limit } = req.valid.query;
    const filter = { user: req.userId };
    if (type) filter.type = type;
    if (category) filter.category = category;
    if (wallet) filter.wallet = wallet;
    if (from || to) {
      filter.date = {};
      if (from) filter.date.$gte = from;
      if (to) filter.date.$lte = to;
    }
    if (q) filter.note = { $regex: escapeRegex(q), $options: 'i' };

    const [items, total] = await Promise.all([
      Transaction.find(filter)
        .sort({ date: -1, createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .populate(POPULATE),
      Transaction.countDocuments(filter),
    ]);

    res.json({
      transactions: items.map((t) => t.toPublic()),
      page,
      limit,
      total,
      hasMore: page * limit < total,
    });
  })
);

router.get(
  '/:id',
  validate(s.idParam, 'params'),
  asyncHandler(async (req, res) => {
    const tx = await Transaction.findOne({ _id: req.valid.params.id, user: req.userId }).populate(POPULATE);
    if (!tx) throw new AppError(404, 'Transaction not found', 'NOT_FOUND');
    res.json({ transaction: tx.toPublic() });
  })
);

router.post(
  '/',
  validate(s.transaction.create),
  asyncHandler(async (req, res) => {
    const body = req.body;
    await assertRefs(req.userId, body);
    const tx = await Transaction.create({
      user: req.userId,
      type: body.type,
      amount: body.amount,
      category: body.category,
      wallet: body.wallet,
      note: body.note,
      date: body.date || new Date(),
    });
    await tx.populate(POPULATE);
    res.status(201).json({ transaction: tx.toPublic() });
  })
);

router.patch(
  '/:id',
  validate(s.idParam, 'params'),
  validate(s.transaction.update),
  asyncHandler(async (req, res) => {
    const tx = await Transaction.findOne({ _id: req.valid.params.id, user: req.userId });
    if (!tx) throw new AppError(404, 'Transaction not found', 'NOT_FOUND');

    const next = {
      type: req.body.type ?? tx.type,
      category: req.body.category ?? tx.category.toString(),
      wallet: req.body.wallet ?? tx.wallet.toString(),
    };
    await assertRefs(req.userId, next);

    for (const key of ['type', 'amount', 'category', 'wallet', 'note', 'date']) {
      if (req.body[key] !== undefined) tx[key] = req.body[key];
    }
    await tx.save();
    await tx.populate(POPULATE);
    res.json({ transaction: tx.toPublic() });
  })
);

router.delete(
  '/:id',
  validate(s.idParam, 'params'),
  asyncHandler(async (req, res) => {
    const result = await Transaction.deleteOne({ _id: req.valid.params.id, user: req.userId });
    if (result.deletedCount === 0) throw new AppError(404, 'Transaction not found', 'NOT_FOUND');
    res.status(204).end();
  })
);

module.exports = router;
