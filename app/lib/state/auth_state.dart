import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/repository.dart';
import '../core/token_storage.dart';
import '../models/models.dart';

enum AuthStatus { checking, signedIn, signedOut, offline }

class AuthState extends ChangeNotifier {
  final Repository repo;
  final TokenStorage storage;

  AuthStatus status = AuthStatus.checking;
  AppUser? user;

  AuthState(this.repo, this.storage) {
    repo.api.onSessionExpired = _expire;
  }

  /// On launch: if we hold tokens, confirm them with the server.
  Future<void> bootstrap() async {
    status = AuthStatus.checking;
    notifyListeners();
    final refresh = await storage.refreshToken;
    if (refresh == null) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    try {
      user = await repo.me();
      status = AuthStatus.signedIn;
    } on ApiException catch (e) {
      if (e.isNetwork) {
        status = AuthStatus.offline;
      } else {
        await storage.clear();
        status = AuthStatus.signedOut;
      }
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final (u, access, refresh) = await repo.login(email.trim(), password);
    await storage.save(accessToken: access, refreshToken: refresh);
    user = u;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    final (u, access, refresh) = await repo.register(name.trim(), email.trim(), password);
    await storage.save(accessToken: access, refreshToken: refresh);
    user = u;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> logout() async {
    final refresh = await storage.refreshToken;
    if (refresh != null) {
      try {
        await repo.logout(refresh);
      } catch (_) {
        // Still sign out locally if the server can't be reached.
      }
    }
    await storage.clear();
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> updateProfile({String? name, double? monthlyBudget}) async {
    user = await repo.updateMe(name: name, monthlyBudget: monthlyBudget);
    notifyListeners();
  }

  Future<void> changePassword(String current, String next) async {
    final (access, refresh) = await repo.changePassword(current, next);
    await storage.save(accessToken: access, refreshToken: refresh);
  }

  Future<void> deleteAccount(String password) async {
    await repo.deleteAccount(password);
    await storage.clear();
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  void _expire() {
    if (status != AuthStatus.signedIn) return;
    storage.clear();
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
