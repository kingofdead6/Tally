import '../models/models.dart';
import 'api_client.dart';

/// Every API call the app makes, in one place.
class Repository {
  final ApiClient api;
  Repository(this.api);

  Map<String, dynamic> _map(dynamic d) => (d as Map).cast<String, dynamic>();
  List<Map<String, dynamic>> _list(dynamic d) => (d as List).map((e) => _map(e)).toList();

  // Auth --------------------------------------------------------------------
  Future<(AppUser, String, String)> register(String name, String email, String password) async {
    final d = _map(await api.postAuth('/auth/register', {'name': name, 'email': email, 'password': password}));
    return (AppUser.fromJson(_map(d['user'])), d['accessToken'] as String, d['refreshToken'] as String);
  }

  Future<(AppUser, String, String)> login(String email, String password) async {
    final d = _map(await api.postAuth('/auth/login', {'email': email, 'password': password}));
    return (AppUser.fromJson(_map(d['user'])), d['accessToken'] as String, d['refreshToken'] as String);
  }

  Future<void> logout(String refreshToken) async {
    await api.postAuth('/auth/logout', {'refreshToken': refreshToken});
  }

  // Account -----------------------------------------------------------------
  Future<AppUser> me() async => AppUser.fromJson(_map(_map(await api.get('/users/me'))['user']));

  Future<AppUser> updateMe({String? name, double? monthlyBudget}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (monthlyBudget != null) body['monthlyBudget'] = monthlyBudget;
    return AppUser.fromJson(_map(_map(await api.patch('/users/me', body))['user']));
  }

  Future<(String, String)> changePassword(String current, String next) async {
    final d = _map(await api.patch('/users/me/password', {'currentPassword': current, 'newPassword': next}));
    return (d['accessToken'] as String, d['refreshToken'] as String);
  }

  Future<void> deleteAccount(String password) => api.delete('/users/me', {'password': password});

  // Categories --------------------------------------------------------------
  Future<List<TxCategory>> categories() async =>
      _list(_map(await api.get('/categories'))['categories']).map(TxCategory.fromJson).toList();

  Future<TxCategory> createCategory(
          {required String name, required TxType type, required String icon, required String color}) async =>
      TxCategory.fromJson(_map(_map(await api.post('/categories', {
        'name': name,
        'type': txTypeName(type),
        'icon': icon,
        'color': color,
      }))['category']));

  Future<TxCategory> updateCategory(String id, {String? name, String? icon, String? color}) async =>
      TxCategory.fromJson(_map(_map(await api.patch('/categories/$id', {
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
      }))['category']));

  Future<void> deleteCategory(String id) => api.delete('/categories/$id');

  // Wallets -----------------------------------------------------------------
  Future<List<Wallet>> wallets() async =>
      _list(_map(await api.get('/wallets'))['wallets']).map(Wallet.fromJson).toList();

  Future<void> createWallet({required String name, required String icon, required String color, double? initial}) =>
      api.post('/wallets', {
        'name': name,
        'icon': icon,
        'color': color,
        if (initial != null) 'initialBalance': initial,
      });

  Future<void> updateWallet(String id, {String? name, String? icon, String? color, double? initial}) =>
      api.patch('/wallets/$id', {
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (initial != null) 'initialBalance': initial,
      });

  Future<void> deleteWallet(String id) => api.delete('/wallets/$id');

  // Transactions --------------------------------------------------------------
  Future<TxnPage> transactions({
    TxType? type,
    String? category,
    String? wallet,
    DateTime? from,
    DateTime? to,
    String? q,
    int page = 1,
    int limit = 30,
  }) async {
    final d = _map(await api.get('/transactions', query: {
      'type': type == null ? null : txTypeName(type),
      'category': category,
      'wallet': wallet,
      'from': from,
      'to': to,
      'q': q,
      'page': page,
      'limit': limit,
    }));
    return TxnPage(
      _list(d['transactions']).map(Txn.fromJson).toList(),
      (d['total'] as num).toInt(),
      d['hasMore'] == true,
    );
  }

  Map<String, dynamic> _txBody(TxType type, double amount, String category, String wallet, String note, DateTime date) =>
      {
        'type': txTypeName(type),
        'amount': amount,
        'category': category,
        'wallet': wallet,
        'note': note,
        'date': date.toUtc().toIso8601String(),
      };

  Future<Txn> createTransaction({
    required TxType type,
    required double amount,
    required String category,
    required String wallet,
    required String note,
    required DateTime date,
  }) async =>
      Txn.fromJson(_map(_map(await api.post('/transactions', _txBody(type, amount, category, wallet, note, date)))[
          'transaction']));

  Future<Txn> updateTransaction(
    String id, {
    required TxType type,
    required double amount,
    required String category,
    required String wallet,
    required String note,
    required DateTime date,
  }) async =>
      Txn.fromJson(_map(_map(await api.patch('/transactions/$id', _txBody(type, amount, category, wallet, note, date)))[
          'transaction']));

  Future<void> deleteTransaction(String id) => api.delete('/transactions/$id');

  // Stats -------------------------------------------------------------------
  Future<MoneySummary> summary({DateTime? from, DateTime? to}) async =>
      MoneySummary.fromJson(_map(await api.get('/stats/summary', query: {'from': from, 'to': to})));

  Future<(double, List<CategoryShare>)> byCategory(TxType type, {DateTime? from, DateTime? to}) async {
    final d = _map(await api.get('/stats/by-category', query: {'type': txTypeName(type), 'from': from, 'to': to}));
    return ((d['total'] as num).toDouble(), _list(d['categories']).map(CategoryShare.fromJson).toList());
  }

  Future<List<MonthPoint>> trend({int months = 6}) async =>
      _list(_map(await api.get('/stats/trend', query: {'months': months}))['months'])
          .map(MonthPoint.fromJson)
          .toList();
}
