// Icon keys the Flutter app knows how to draw. Anything else is rejected,
// so the client never has to render an unknown/user-supplied value.
const ICONS = [
  // income sources
  'salary', 'freelance', 'business', 'gift', 'investment', 'refund', 'rental', 'bonus', 'sale',
  // expenses
  'food', 'groceries', 'coffee', 'transport', 'fuel', 'car', 'home', 'bills', 'phone', 'internet',
  'shopping', 'clothes', 'health', 'education', 'entertainment', 'sport', 'travel', 'family',
  'pets', 'charity', 'beauty', 'tools', 'subscription',
  // wallets
  'cash', 'card', 'bank', 'mobile', 'savings',
  // generic
  'other',
];

const DEFAULT_CATEGORIES = [
  // Income sources
  { type: 'income', name: 'Salary', icon: 'salary', color: '#22C55E' },
  { type: 'income', name: 'Freelance', icon: 'freelance', color: '#14B8A6' },
  { type: 'income', name: 'Business', icon: 'business', color: '#0EA5E9' },
  { type: 'income', name: 'Gift', icon: 'gift', color: '#A855F7' },
  { type: 'income', name: 'Investment', icon: 'investment', color: '#F59E0B' },
  { type: 'income', name: 'Other income', icon: 'other', color: '#64748B' },
  // Expenses
  { type: 'expense', name: 'Food', icon: 'food', color: '#F97316' },
  { type: 'expense', name: 'Groceries', icon: 'groceries', color: '#84CC16' },
  { type: 'expense', name: 'Transport', icon: 'transport', color: '#3B82F6' },
  { type: 'expense', name: 'Rent & Bills', icon: 'bills', color: '#EF4444' },
  { type: 'expense', name: 'Phone & Internet', icon: 'phone', color: '#06B6D4' },
  { type: 'expense', name: 'Shopping', icon: 'shopping', color: '#EC4899' },
  { type: 'expense', name: 'Health', icon: 'health', color: '#10B981' },
  { type: 'expense', name: 'Education', icon: 'education', color: '#6366F1' },
  { type: 'expense', name: 'Entertainment', icon: 'entertainment', color: '#8B5CF6' },
  { type: 'expense', name: 'Family', icon: 'family', color: '#F43F5E' },
  { type: 'expense', name: 'Other expense', icon: 'other', color: '#64748B' },
];

const DEFAULT_WALLETS = [{ name: 'Cash', icon: 'cash', color: '#22C55E', initialBalance: 0 }];

// Hard ceiling for one transaction (1 billion DA) — stops typos like 1e20.
const MAX_AMOUNT = 1_000_000_000;

module.exports = { ICONS, DEFAULT_CATEGORIES, DEFAULT_WALLETS, MAX_AMOUNT };
