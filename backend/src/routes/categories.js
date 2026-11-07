const express = require('express');
const Category = require('../models/Category');
const Transaction = require('../models/Transaction');
const validate = require('../middleware/validate');
const s = require('../utils/schemas');
const { asyncHandler, AppError } = require('../utils/errors');

const router = express.Router();

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const cats = await Category.find({ user: req.userId }).sort({ type: 1, name: 1 });
    res.json({ categories: cats.map((c) => c.toPublic()) });
  })
);

router.post(
  '/',
  validate(s.category.create),
  asyncHandler(async (req, res) => {
    const count = await Category.countDocuments({ user: req.userId });
    if (count >= 200) throw new AppError(400, 'Category limit reached', 'LIMIT');
    const cat = await Category.create({ ...req.body, user: req.userId });
    res.status(201).json({ category: cat.toPublic() });
  })
);

router.patch(
  '/:id',
  validate(s.idParam, 'params'),
  validate(s.category.update),
  asyncHandler(async (req, res) => {
    // Ownership is part of the lookup — another user's id is simply "not found".
    const cat = await Category.findOneAndUpdate(
      { _id: req.valid.params.id, user: req.userId },
      { $set: req.body },
      { new: true, runValidators: true }
    );
    if (!cat) throw new AppError(404, 'Category not found', 'NOT_FOUND');
    res.json({ category: cat.toPublic() });
  })
);

router.delete(
  '/:id',
  validate(s.idParam, 'params'),
  asyncHandler(async (req, res) => {
    const filter = { _id: req.valid.params.id, user: req.userId };
    const cat = await Category.findOne(filter);
    if (!cat) throw new AppError(404, 'Category not found', 'NOT_FOUND');

    const used = await Transaction.countDocuments({ user: req.userId, category: cat._id });
    if (used > 0) {
      throw new AppError(
        409,
        `This category is used by ${used} transaction${used > 1 ? 's' : ''}. Change or delete them first.`,
        'IN_USE'
      );
    }
    await Category.deleteOne(filter);
    res.status(204).end();
  })
);

module.exports = router;
