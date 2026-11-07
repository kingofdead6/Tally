import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/money.dart';
import '../core/repository.dart';
import '../models/models.dart';

/// Shared data for the signed-in user: categories, wallets, this month's
/// totals and the latest transactions. Screens that need their own filtered
/// lists watch [revision] and refetch when it changes.
class FinanceState extends ChangeNotifier {
  final Repository repo;
  FinanceState(this.repo);

  List<TxCategory> categories = [];
  List<Wallet> wallets = [];
  MoneySummary month = const MoneySummary();
  List<Txn> recent = [];

  bool loading = false;
  bool loaded = false;
  String? error;

  /// Bumped after every change so filtered lists know to reload.
  int revision = 0;

  List<TxCategory> categoriesOf(TxType type) => categories.where((c) => c.type == type).toList();

  Future<void> loadAll() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        repo.categories(),
        repo.wallets(),
        repo.summary(from: Dates.startOfMonth(now), to: Dates.endOfMonth(now)),
        repo.transactions(limit: 8),
      ]);
      categories = results[0] as List<TxCategory>;
      wallets = results[1] as List<Wallet>;
      month = results[2] as MoneySummary;
      recent = (results[3] as TxnPage).items;
      loaded = true;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Reload balances + recent after a transaction change.
  Future<void> _afterChange() async {
    revision++;
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        repo.wallets(),
        repo.summary(from: Dates.startOfMonth(now), to: Dates.endOfMonth(now)),
        repo.transactions(limit: 8),
      ]);
      wallets = results[0] as List<Wallet>;
      month = results[1] as MoneySummary;
      recent = (results[2] as TxnPage).items;
    } on ApiException catch (_) {
      // Keep current data; next pull-to-refresh fixes it.
    }
    notifyListeners();
  }

  // Transactions --------------------------------------------------------------
  Future<void> saveTransaction({
    String? id,
    required TxType type,
    required double amount,
    required String category,
    required String wallet,
    required String note,
    required DateTime date,
  }) async {
    if (id == null) {
      await repo.createTransaction(
          type: type, amount: amount, category: category, wallet: wallet, note: note, date: date);
    } else {
      await repo.updateTransaction(id,
          type: type, amount: amount, category: category, wallet: wallet, note: note, date: date);
    }
    await _afterChange();
  }

  Future<void> deleteTransaction(String id) async {
    await repo.deleteTransaction(id);
    await _afterChange();
  }

  // Categories --------------------------------------------------------------
  Future<void> saveCategory({
    String? id,
    required String name,
    required TxType type,
    required String icon,
    required String color,
  }) async {
    if (id == null) {
      await repo.createCategory(name: name, type: type, icon: icon, color: color);
    } else {
      await repo.updateCategory(id, name: name, icon: icon, color: color);
    }
    categories = await repo.categories();
    revision++;
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await repo.deleteCategory(id);
    categories = await repo.categories();
    notifyListeners();
  }

  // Wallets -----------------------------------------------------------------
  Future<void> saveWallet({
    String? id,
    required String name,
    required String icon,
    required String color,
    required double initial,
  }) async {
    if (id == null) {
      await repo.createWallet(name: name, icon: icon, color: color, initial: initial);
    } else {
      await repo.updateWallet(id, name: name, icon: icon, color: color, initial: initial);
    }
    await _afterChange();
  }

  Future<void> deleteWallet(String id) async {
    await repo.deleteWallet(id);
    await _afterChange();
  }

  void reset() {
    categories = [];
    wallets = [];
    month = const MoneySummary();
    recent = [];
    loaded = false;
    error = null;
    revision = 0;
    notifyListeners();
  }
}
