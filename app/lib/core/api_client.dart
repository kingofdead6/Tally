import 'package:dio/dio.dart';

import 'config.dart';
import 'token_storage.dart';

class ApiException implements Exception {
  final String message;
  final String code;
  final int? status;
  ApiException(this.message, {this.code = 'ERROR', this.status});

  bool get isNetwork => code == 'NETWORK';

  @override
  String toString() => message;
}

/// Dio wrapper that attaches the access token and, when it expires,
/// swaps the refresh token for a new pair once and retries the request.
class ApiClient {
  final TokenStorage storage;
  late final Dio _dio;
  late final Dio _bare; // no interceptors — used for refresh
  Future<bool>? _refreshing;

  /// Called when the session can no longer be refreshed (forces logout).
  void Function()? onSessionExpired;

  ApiClient(this.storage) {
    final options = BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    );
    _dio = Dio(options);
    _bare = Dio(options);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (req, handler) async {
          final token = await storage.accessToken;
          if (token != null) req.headers['Authorization'] = 'Bearer $token';
          handler.next(req);
        },
        onError: (err, handler) async {
          final req = err.requestOptions;
          final isAuthCall = req.path.startsWith('/auth/');
          final alreadyRetried = req.extra['retried'] == true;
          if (err.response?.statusCode == 401 && !isAuthCall && !alreadyRetried) {
            final ok = await _refresh();
            if (ok) {
              try {
                final token = await storage.accessToken;
                req.headers['Authorization'] = 'Bearer $token';
                req.extra['retried'] = true;
                final response = await _dio.fetch(req);
                return handler.resolve(response);
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
            // Tokens are cleared only when the server rejected the refresh,
            // so a flaky connection never logs the user out.
            if (await storage.refreshToken == null) onSessionExpired?.call();
          }
          handler.next(err);
        },
      ),
    );
  }

  /// Only one refresh runs at a time; parallel 401s wait for the same result.
  Future<bool> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = await storage.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await _bare.post('/auth/refresh', data: {'refreshToken': refresh});
      final data = res.data as Map<String, dynamic>;
      await storage.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } on DioException catch (e) {
      // Only drop tokens when the server actually rejected them.
      if (e.response?.statusCode == 401) await storage.clear();
      return false;
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, [Object? body]) => _send(() => _dio.post(path, data: body));

  Future<dynamic> patch(String path, [Object? body]) => _send(() => _dio.patch(path, data: body));

  Future<dynamic> delete(String path, [Object? body]) => _send(() => _dio.delete(path, data: body));

  /// Raw call without the refresh interceptor (login/register/refresh/logout).
  Future<dynamic> postAuth(String path, Object body) => _send(() => _bare.post(path, data: body));

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      out[k] = v is DateTime ? v.toUtc().toIso8601String() : v;
    });
    return out;
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      return res.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException("Can't reach the server. Check your connection and try again.", code: 'NETWORK');
    }
    final data = res.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        (err['message'] ?? 'Something went wrong').toString(),
        code: (err['code'] ?? 'ERROR').toString(),
        status: res.statusCode,
      );
    }
    return ApiException('Something went wrong (${res.statusCode}).', status: res.statusCode);
  }
}
