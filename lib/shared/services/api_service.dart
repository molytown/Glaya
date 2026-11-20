import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';

class ApiService {
  static Dio? _dioInstance;

  /// Current zone identifier — included in content cache keys so a zone
  /// change automatically misses the cache and fetches fresh content.
  static String? zoneKey;

  /// Zone-scoped public GET endpoints eligible for short-lived caching.
  static const _cacheablePaths = [
    '/hero',
    '/professionals',
    '/services/public',
    '/reels',
    '/reels/priority',
    '/promotions/active',
    '/categories/public',
    '/salons',
    '/magazine',
    '/portfolio',
  ];

  static const _cacheTtl = Duration(days: 30);
  static const _cachePrefix = 'glaya_zone_cache:';

  /// How old a cache entry must be before a read triggers a silent background
  /// revalidation. Fresh entries are served without any network call.
  static const _revalidateAfter = Duration(minutes: 2);

  /// Cache keys with an in-flight background revalidation (dedupes bursts).
  static final _inflightRefreshes = <String>{};

  /// Emits the cache key whenever fresh content is written to the cache
  /// (including silent background revalidations). Providers can listen and
  /// re-resolve so new data appears without an app restart.
  static final _contentRefreshed = StreamController<String>.broadcast();
  static Stream<String> get onContentRefreshed => _contentRefreshed.stream;

  static bool _isCacheableGet(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return false;
    final path = options.path;
    return _cacheablePaths.any((p) =>
        path == p ||
        path.startsWith('$p/') ||
        path.startsWith('/api/v1$p') ||
        path.startsWith('/api/v1$p/'));
  }

  static String _cacheKey(RequestOptions options) {
    final params = Map.of(options.queryParameters)
      ..removeWhere((k, v) => v == null);
    final sorted = params.keys.toList()..sort();
    final qs = sorted.map((k) => '$k=${params[k]}').join('&');
    return '$_cachePrefix${options.path}|$qs|zone=${zoneKey ?? 'none'}';
  }

  /// Returns the raw cache entry ({ts, data}) or null when missing/expired.
  static Future<Map<String, dynamic>?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final ts = entry['ts'] as int? ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - ts > _cacheTtl.inMilliseconds)
        return null;
      return entry;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(String key, dynamic data) async {
    try {
      if (data is! Map) return;
      final raw = jsonEncode(data);
      if (raw.length > 400000) return; // skip very large payloads
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          key,
          jsonEncode({
            'ts': DateTime.now().millisecondsSinceEpoch,
            'data': data,
          }));
    } catch (_) {}
  }

  /// Drop all cached zone content (call on manual location change).
  static Future<void> clearContentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((k) => k.startsWith(_cachePrefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  static Dio get dio {
    if (_dioInstance == null) {
      _dioInstance = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ));
      setupInterceptors();
    }
    return _dioInstance!;
  }

  static void updateBaseUrl() {
    if (_dioInstance != null) {
      _dioInstance!.options.baseUrl = ApiConstants.baseUrl;
    }
  }

  static Options multipartOptions() => Options();

  static Future<FormData> buildMultipart({
    required Map<String, String> fields,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    required String fileField,
  }) async {
    final fileData = fileBytes != null
        ? MultipartFile.fromBytes(fileBytes, filename: fileName ?? 'upload.jpg')
        : (filePath != null ? await MultipartFile.fromFile(filePath) : null);

    return FormData.fromMap({
      ...fields,
      if (fileData != null) fileField: fileData,
    });
  }

  static bool _isRefreshing = false;
  static bool _interceptorsSetup = false;

  static void setupInterceptors() {
    if (_interceptorsSetup) return;
    _interceptorsSetup = true;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Stale-while-revalidate: serve cached zone content instantly (even if
        // stale), then silently refresh it in the background so the next read
        // gets fresh data. UI updates when providers are re-invalidated.
        if (_isCacheableGet(options)) {
          final key = _cacheKey(options);
          if (options.extra['__skipCacheRead'] != true) {
            final entry = await _readCache(key);
            if (entry != null) {
              final data = entry['data'] as Map<String, dynamic>?;
              final ts = entry['ts'] as int? ?? 0;
              final age = DateTime.now().millisecondsSinceEpoch - ts;
              // Only revalidate in the background once the entry is older than
              // _revalidateAfter — fresh entries resolve with zero network I/O.
              if (data != null &&
                  age > _revalidateAfter.inMilliseconds &&
                  !_inflightRefreshes.contains(key)) {
                _inflightRefreshes.add(key);
                try {
                  final refreshOptions = options.copyWith();
                  refreshOptions.extra['__skipCacheRead'] = true;
                  refreshOptions.extra['__cacheKey'] = key;
                  dio
                      .fetch(refreshOptions)
                      .catchError((_) => Response(
                            requestOptions: refreshOptions,
                            statusCode: 0,
                          ))
                      .whenComplete(() => _inflightRefreshes.remove(key));
                } catch (_) {
                  _inflightRefreshes.remove(key);
                }
              }
              if (data != null) {
                return handler.resolve(Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: data,
                ));
              }
            }
          }
          options.extra['__cacheKey'] = key;
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final key = response.requestOptions.extra['__cacheKey'] as String?;
        if (key != null) {
          _writeCache(key, response.data);
          _contentRefreshed.add(key);
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && !_isRefreshing) {
          _isRefreshing = true;
          final refreshToken = await StorageService.getRefreshToken();
          if (refreshToken != null) {
            try {
              final response = await dio
                  .post('/auth/refresh', data: {'refreshToken': refreshToken});
              final newAccessToken =
                  response.data['data']['accessToken'] as String;
              final newRefreshToken =
                  response.data['data']['refreshToken'] as String;
              await StorageService.setToken(newAccessToken);
              await StorageService.setRefreshToken(newRefreshToken);

              error.requestOptions.headers['Authorization'] =
                  'Bearer $newAccessToken';
              final retryResponse = await dio.request(
                error.requestOptions.path,
                options: Options(method: error.requestOptions.method),
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
              );
              _isRefreshing = false;
              return handler.resolve(retryResponse);
            } catch (refreshError) {
              // Refresh token is also invalid - clear all stored data
              await StorageService.clearAll();
              _isRefreshing = false;
              // Return the original 401 error so the app can handle redirect to login
              return handler.next(error);
            }
          } else {
            // No refresh token available - clear everything
            await StorageService.clearAll();
            _isRefreshing = false;
          }
        } else if (error.response?.statusCode == 401 && _isRefreshing) {
          // Already refreshing, just return error to avoid infinite loop
          return handler.next(error);
        }
        return handler.next(error);
      },
    ));
  }

  // Onboarding API methods
  static Future<List<Map<String, dynamic>>> getOnboardingMessages() async {
    final response = await dio.get('/api/v1/onboarding/messages');
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<void> sendOnboardingReply(String reply) async {
    await dio.post('/api/v1/onboarding/reply', data: {'reply': reply});
  }

  static Future<void> markOnboardingAsRead() async {
    await dio.post('/api/v1/onboarding/read');
  }
}
