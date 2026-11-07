import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens live in the Android Keystore / iOS Keychain, never in plain prefs.
class TokenStorage {
  static const _access = 'tally_access';
  static const _refresh = 'tally_refresh';
  static const _theme = 'tally_theme';

  final FlutterSecureStorage _store = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  String? _cachedAccess;

  Future<String?> get accessToken async => _cachedAccess ??= await _store.read(key: _access);
  Future<String?> get refreshToken => _store.read(key: _refresh);

  Future<void> save({required String accessToken, required String refreshToken}) async {
    _cachedAccess = accessToken;
    await _store.write(key: _access, value: accessToken);
    await _store.write(key: _refresh, value: refreshToken);
  }

  Future<void> clear() async {
    _cachedAccess = null;
    await _store.delete(key: _access);
    await _store.delete(key: _refresh);
  }

  Future<String?> readTheme() => _store.read(key: _theme);
  Future<void> writeTheme(String value) => _store.write(key: _theme, value: value);
}
