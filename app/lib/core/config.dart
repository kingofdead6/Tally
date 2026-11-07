import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static const _fallback = 'http://10.0.2.2:5000/api';

  /// Read from the app's .env (API_URL). Falls back to the Android emulator address.
  static String get apiUrl {
    String? value;
    try {
      value = dotenv.env['API_URL'];
    } catch (_) {
      value = null;
    }
    final url = (value == null || value.trim().isEmpty) ? _fallback : value.trim();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
