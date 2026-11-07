const express = require('express');
const Wallet = require('../models/Wallet');
const Transaction = require('../models/Transaction');
const validate = require('../middleware/validate');
const s = require('../utils/schemas');
const { asyncHandler, AppError } = require('../utils/errors');
const { netByWallet, round2 } = require('../utils/balances');

const router = express.Router();

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const [wallets, nets] = await Promise.all([
      Wallet.find({ user: req.userId }).sort({ createdAt: 1 }),
      netByWallet(req.userId),
    ]);
    res.json({
      wallets: wallets.map((w) => w.toPublic(round2(w.initialBalance + (nets.get(w._id.toString()) || 0)))),
    });
  })
);

router.post(
  '/',
  validate(s.wallet.create),
  asyncHandler(async (req, res) => {
    const count = await Wallet.countDocuments({ user: req.userId });
    if (count >= 30) throw new AppError(400, 'Wallet limit reached', 'LIMIT');
    const wallet = await Wallet.create({ ...req.body, user: req.userId });
    res.status(201).json({ wallet: wallet.toPublic() });
  })
);

router.patch(
  '/:id',
  validate(s.idParam, 'params'),
  validate(s.wallet.update),
  asyncHandler(async (req, res) => {
    const wallet = await Wallet.findOneAndUpdate(
      { _id: req.valid.params.id, user: req.userId },
      { $set: req.body },
      { new: true, runValidators: true }
    );
    if (!wallet) throw new AppError(404, 'Wallet not found', 'NOT_FOUND');
    const nets = await netByWallet(req.userId);
    res.json({ wallet: wallet.toPublic(round2(wallet.initialBalance + (nets.get(wallet._id.toString()) || 0))) });
  })
);

router.delete(
  '/:id',
  validate(s.idParam, 'params'),
  asyncHandler(async (req, res) => {
    const filter = { _id: req.valid.params.id, user: req.userId };
    const wallet = await Wallet.findOne(filter);
    if (!wallet) throw new AppError(404, 'Wallet not found', 'NOT_FOUND');

    const total = await Wallet.countDocuments({ user: req.userId });
    if (total <= 1) throw new AppError(409, 'You need at least one wallet', 'LAST_WALLET');

    const used = await Transaction.countDocuments({ user: req.userId, wallet: wallet._id });
    if (used > 0) {
      throw new AppError(
        409,
        `This wallet has ${used} transaction${used > 1 ? 's' : ''}. Move or delete them first.`,
        'IN_USE'
      );
    }
    await Wallet.deleteOne(filter);
    res.status(204).end();
  })
);

module.exports = router;
