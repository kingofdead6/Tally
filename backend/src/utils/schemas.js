const { z } = require('zod');
const mongoose = require('mongoose');
const { ICONS, MAX_AMOUNT } = require('./constants');

const objectId = z
  .string()
  .refine((v) => mongoose.Types.ObjectId.isValid(v) && /^[a-f0-9]{24}$/i.test(v), 'Invalid id');

const name = (max) => z.string().trim().min(1, 'Required').max(max);
const icon = z.enum(ICONS);
const color = z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Color must look like #RRGGBB');
const type = z.enum(['income', 'expense']);

// Round to centimes so floating-point noise never reaches the database.
const money = z
  .number({ invalid_type_error: 'Amount must be a number' })
  .finite()
  .transform((v) => Math.round(v * 100) / 100);

const positiveAmount = money.refine((v) => v > 0 && v <= MAX_AMOUNT, `Amount must be between 0.01 and ${MAX_AMOUNT}`);
const signedAmount = money.refine((v) => Math.abs(v) <= MAX_AMOUNT, 'Amount too large');

const email = z.string().trim().toLowerCase().email('Invalid email').max(254);
const password = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(128, 'Password is too long');

const isoDate = z.coerce.date().refine((d) => !Number.isNaN(d.getTime()), 'Invalid date');

module.exports = {
  z,
  objectId,
  name,
  icon,
  color,
  type,
  positiveAmount,
  signedAmount,
  email,
  password,
  isoDate,

  auth: {
    register: z.object({ name: name(60), email, password }).strict(),
    login: z.object({ email, password: z.string().min(1).max(128) }).strict(),
    refresh: z.object({ refreshToken: z.string().min(20).max(200) }).strict(),
  },

  user: {
    update: z
      .object({
        name: name(60).optional(),
        monthlyBudget: money.refine((v) => v >= 0 && v <= MAX_AMOUNT, 'Invalid budget').optional(),
      })
      .strict(),
    changePassword: z.object({ currentPassword: z.string().min(1).max(128), newPassword: password }).strict(),
    remove: z.object({ password: z.string().min(1).max(128) }).strict(),
  },

  category: {
    create: z.object({ name: name(40), type, icon, color }).strict(),
    update: z.object({ name: name(40).optional(), icon: icon.optional(), color: color.optional() }).strict(),
  },

  wallet: {
    create: z.object({ name: name(40), icon, color, initialBalance: signedAmount.optional() }).strict(),
    update: z
      .object({
        name: name(40).optional(),
        icon: icon.optional(),
        color: color.optional(),
        initialBalance: signedAmount.optional(),
      })
      .strict(),
  },

  transaction: {
    create: z
      .object({
        type,
        amount: positiveAmount,
        category: objectId,
        wallet: objectId,
        note: z.string().trim().max(200).optional().default(''),
        date: isoDate.optional(),
      })
      .strict(),
    update: z
      .object({
        type: type.optional(),
        amount: positiveAmount.optional(),
        category: objectId.optional(),
        wallet: objectId.optional(),
        note: z.string().trim().max(200).optional(),
        date: isoDate.optional(),
      })
      .strict(),
    list: z.object({
      type: type.optional(),
      category: objectId.optional(),
      wallet: objectId.optional(),
      from: isoDate.optional(),
      to: isoDate.optional(),
      q: z.string().trim().max(100).optional(),
      page: z.coerce.number().int().min(1).max(10_000).default(1),
      limit: z.coerce.number().int().min(1).max(100).default(30),
    }),
  },

  stats: {
    range: z.object({ from: isoDate.optional(), to: isoDate.optional() }),
    byCategory: z.object({ type: type.default('expense'), from: isoDate.optional(), to: isoDate.optional() }),
    trend: z.object({ months: z.coerce.number().int().min(1).max(24).default(6) }),
  },

  idParam: z.object({ id: objectId }),
};
