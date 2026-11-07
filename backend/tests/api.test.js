// End-to-end test of the Tally API against an in-memory MongoDB.
// Run with:  npm test   (downloads a MongoDB binary the first time)
const path = require('path');
const BACKEND = path.join(__dirname, '..');
const req = (m) => require(path.join(BACKEND, 'node_modules', m));
const { MongoMemoryServer } = req('mongodb-memory-server');

(async () => {
  const mongo = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongo.getUri('tally');
  process.env.JWT_ACCESS_SECRET = 'x'.repeat(48);
  process.env.NODE_ENV = 'test';
  const mongoose = req('mongoose');
  await require(path.join(BACKEND, 'src/config/db.js'))();
  const app = require(path.join(BACKEND, 'src/app.js'));
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/api`;

  let pass = 0, fail = 0;
  const check = (name, cond, extra) => {
    if (cond) { pass++; console.log('  ok  ', name); }
    else { fail++; console.log('  FAIL', name, extra !== undefined ? JSON.stringify(extra) : ''); }
  };
  async function call(method, url, body, token) {
    const r = await fetch(base + url, {
      method,
      headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    let json = null; try { json = await r.json(); } catch {}
    return { status: r.status, body: json };
  }

  // Auth
  let r = await call('POST', '/auth/register', { name: 'Youcef', email: 'Y@test.dz', password: 'password123' });
  check('register 201', r.status === 201, r.body);
  check('no hash in user', !JSON.stringify(r.body).includes('passwordHash'));
  let { accessToken, refreshToken } = r.body;
  r = await call('POST', '/auth/register', { name: 'X', email: 'y@test.dz', password: 'password123' });
  check('duplicate email 409', r.status === 409);
  r = await call('POST', '/auth/register', { name: 'X', email: 'z@test.dz', password: 'short' });
  check('weak password 400', r.status === 400);
  r = await call('POST', '/auth/register', { name: 'X', email: 'z@test.dz', password: 'password123', role: 'admin' });
  check('extra field rejected', r.status === 400);
  r = await call('POST', '/auth/login', { email: 'y@test.dz', password: 'wrongpass' });
  check('wrong password 401', r.status === 401);
  r = await call('POST', '/auth/login', { email: { $ne: null }, password: 'x' });
  check('nosql injection rejected 400', r.status === 400);
  r = await call('POST', '/auth/login', { email: 'nobody@test.dz', password: 'wrongpass' });
  check('unknown email same 401', r.status === 401 && r.body.error.code === 'INVALID_CREDENTIALS');
  r = await call('POST', '/auth/login', { email: 'y@test.dz', password: 'password123' });
  check('login 200', r.status === 200);

  // Refresh rotation
  r = await call('POST', '/auth/refresh', { refreshToken });
  check('refresh 200', r.status === 200);
  const oldRefresh = refreshToken;
  ({ accessToken, refreshToken } = r.body);
  r = await call('POST', '/auth/refresh', { refreshToken: oldRefresh });
  check('reused refresh token rejected', r.status === 401);

  r = await call('GET', '/users/me');
  check('no token 401', r.status === 401);
  r = await call('GET', '/users/me', undefined, 'garbage');
  check('bad token 401', r.status === 401);

  // Seeded data
  r = await call('GET', '/categories', undefined, accessToken);
  const cats = r.body.categories;
  check('default categories seeded', cats.length === 17, cats.length);
  const salary = cats.find((c) => c.name === 'Salary');
  const food = cats.find((c) => c.name === 'Food');
  r = await call('GET', '/wallets', undefined, accessToken);
  const cash = r.body.wallets[0];
  check('default wallet seeded', cash && cash.name === 'Cash');

  // Transactions
  r = await call('POST', '/transactions', { type: 'income', amount: 50000, category: salary.id, wallet: cash.id, note: 'October salary' }, accessToken);
  check('income created', r.status === 201, r.body);
  const incomeId = r.body.transaction.id;
  r = await call('POST', '/transactions', { type: 'expense', amount: 1250.555, category: food.id, wallet: cash.id, note: 'Pizza (large)' }, accessToken);
  check('expense created & rounded', r.status === 201 && r.body.transaction.amount === 1250.56, r.body);
  r = await call('POST', '/transactions', { type: 'expense', amount: 100, category: salary.id, wallet: cash.id }, accessToken);
  check('type mismatch rejected', r.status === 400);
  r = await call('POST', '/transactions', { type: 'expense', amount: -5, category: food.id, wallet: cash.id }, accessToken);
  check('negative amount rejected', r.status === 400);
  r = await call('POST', '/transactions', { type: 'expense', amount: 5, category: food.id, wallet: cash.id, user: '000000000000000000000000' }, accessToken);
  check('mass-assign user rejected', r.status === 400);

  r = await call('GET', '/transactions?q=' + encodeURIComponent('(large'), undefined, accessToken);
  check('regex-safe search', r.status === 200 && r.body.total === 1, r.body);
  r = await call('GET', '/transactions?limit=1000', undefined, accessToken);
  check('page size capped', r.status === 400);
  r = await call('GET', '/transactions?type=income', undefined, accessToken);
  check('filter by type', r.body.total === 1);

  r = await call('PATCH', `/transactions/${incomeId}`, { amount: 60000 }, accessToken);
  check('update tx', r.status === 200 && r.body.transaction.amount === 60000);

  r = await call('GET', '/stats/summary', undefined, accessToken);
  check('summary balance', r.body.balance === 58749.44, r.body);
  r = await call('GET', '/stats/by-category?type=expense', undefined, accessToken);
  check('by-category', r.body.categories[0].name === 'Food' && r.body.categories[0].percent === 100, r.body);
  r = await call('GET', '/stats/trend?months=6', undefined, accessToken);
  check('trend 6 months', r.body.months.length === 6, r.body);

  r = await call('GET', '/wallets', undefined, accessToken);
  check('wallet balance', r.body.wallets[0].balance === 58749.44, r.body);

  r = await call('DELETE', `/categories/${food.id}`, undefined, accessToken);
  check('cannot delete used category', r.status === 409);
  r = await call('DELETE', `/wallets/${cash.id}`, undefined, accessToken);
  check('cannot delete last wallet', r.status === 409);

  // IDOR: second user can't touch first user's data
  r = await call('POST', '/auth/register', { name: 'Other', email: 'other@test.dz', password: 'password123' });
  const other = r.body.accessToken;
  r = await call('GET', `/transactions/${incomeId}`, undefined, other);
  check('IDOR read blocked', r.status === 404);
  r = await call('PATCH', `/transactions/${incomeId}`, { amount: 1 }, other);
  check('IDOR update blocked', r.status === 404);
  r = await call('DELETE', `/transactions/${incomeId}`, undefined, other);
  check('IDOR delete blocked', r.status === 404);
  r = await call('PATCH', `/categories/${food.id}`, { name: 'hacked' }, other);
  check('IDOR category blocked', r.status === 404);
  r = await call('GET', '/wallets', undefined, other);
  const otherCash = r.body.wallets[0];
  r = await call('GET', '/categories', undefined, other);
  const otherFood = r.body.categories.find((c) => c.name === 'Food');
  r = await call('POST', '/transactions', { type: 'expense', amount: 5, category: food.id, wallet: otherCash.id }, other);
  check('cannot use another user category', r.status === 400);
  r = await call('POST', '/transactions', { type: 'expense', amount: 5, category: otherFood.id, wallet: cash.id }, other);
  check('cannot use another user wallet', r.status === 400);
  r = await call('GET', '/transactions/not-an-id', undefined, accessToken);
  check('bad id 400', r.status === 400);

  // Account
  r = await call('PATCH', '/users/me', { monthlyBudget: 30000 }, accessToken);
  check('set budget', r.body.user.monthlyBudget === 30000);
  r = await call('PATCH', '/users/me/password', { currentPassword: 'password123', newPassword: 'newpassword456' }, accessToken);
  check('change password', r.status === 200);
  r = await call('POST', '/auth/refresh', { refreshToken });
  check('old sessions revoked after pw change', r.status === 401);
  accessToken = (await call('POST', '/auth/login', { email: 'y@test.dz', password: 'newpassword456' })).body.accessToken;
  r = await call('DELETE', `/transactions/${incomeId}`, undefined, accessToken);
  check('delete tx', r.status === 204);
  r = await call('DELETE', '/users/me', { password: 'nope' }, accessToken);
  check('delete account needs password', r.status === 400);
  r = await call('DELETE', '/users/me', { password: 'newpassword456' }, accessToken);
  check('delete account', r.status === 204);
  const left = await mongoose.connection.db.collection('transactions').countDocuments({});
  check('user data wiped', left === 0, left);

  r = await call('POST', '/auth/login', { email: 'y@test.dz', password: '{bad json' });
  const raw = await fetch(base + '/auth/login', { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{bad' });
  check('malformed json 400', raw.status === 400);

  console.log(`\n${pass} passed, ${fail} failed`);
  server.close();
  await mongoose.disconnect();
  await mongo.stop();
  process.exit(fail ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
