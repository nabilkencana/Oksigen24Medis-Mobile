import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.oksigen24medis.com',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  // --- In-memory token cache ---
  // Primary source for Authorization header. SharedPreferences is only a
  // persistence fallback. This prevents 401s when the platform channel is
  // broken on Hot Restart (SharedPreferences fails silently but memory is fine).
  String? _memoryAccessToken;
  String? _memoryRefreshToken;

  void setMemoryTokens({
    required String accessToken,
    required String refreshToken,
  }) {
    _memoryAccessToken = accessToken;
    _memoryRefreshToken = refreshToken;
  }

  void clearMemoryTokens() {
    _memoryAccessToken = null;
    _memoryRefreshToken = null;
  }

  ApiService._internal() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path.contains('/auth/login')) {
            return handler.next(options);
          }

          // 1. Try in-memory token first (always available even after Hot Restart)
          String? token = _memoryAccessToken;

          // 2. Fallback: read from SharedPreferences (persisted across cold starts)
          if (token == null) {
            try {
              final prefs = await SharedPreferences.getInstance();
              token = prefs.getString('accessToken');
              // Warm up memory cache from disk so subsequent requests are fast
              if (token != null) {
                _memoryAccessToken = token;
                _memoryRefreshToken = prefs.getString('refreshToken');
              }
            } catch (_) {
              // Platform channel broken on Hot Restart — memory cache is sole source
            }
          }

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401 &&
              !e.requestOptions.path.contains('/auth/login') &&
              !e.requestOptions.path.contains('/auth/refresh')) {
            // 1. Try in-memory refresh token first
            String? refreshToken = _memoryRefreshToken;

            // 2. Fallback to SharedPreferences
            if (refreshToken == null) {
              try {
                final prefs = await SharedPreferences.getInstance();
                refreshToken = prefs.getString('refreshToken');
              } catch (_) {}
            }

            if (refreshToken != null) {
              try {
                final refreshResponse = await Dio().post(
                  'https://api.oksigen24medis.com/auth/refresh',
                  options: Options(
                    headers: {'Authorization': 'Bearer $refreshToken'},
                  ),
                );

                if (refreshResponse.data != null &&
                    refreshResponse.data['success'] == true) {
                  final data = refreshResponse.data['data'];
                  final newAccessToken = data['accessToken'] as String;
                  final newRefreshToken = data['refreshToken'] as String;

                  // Update in-memory cache immediately
                  _memoryAccessToken = newAccessToken;
                  _memoryRefreshToken = newRefreshToken;

                  // Persist to SharedPreferences (best-effort)
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('accessToken', newAccessToken);
                    await prefs.setString('refreshToken', newRefreshToken);
                  } catch (_) {}

                  // Retry the original request with the new token
                  final opts = e.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $newAccessToken';

                  final retryResponse = await Dio().request(
                    '${opts.baseUrl}${opts.path}',
                    data: opts.data,
                    queryParameters: opts.queryParameters,
                    options: Options(
                      method: opts.method,
                      headers: opts.headers,
                    ),
                  );
                  return handler.resolve(retryResponse);
                }
              } catch (_) {
                // Refresh failed — clear tokens and force re-login
                clearMemoryTokens();
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('accessToken');
                  await prefs.remove('refreshToken');
                } catch (_) {}
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // Parse response payload dynamically
  dynamic handleResponse(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['success'] == true) {
        return data['data'];
      }
      throw ApiException(
        message: data['message'] ?? 'Request failed',
        messages: List<String>.from(data['messages'] ?? []),
      );
    }
    return data;
  }

  // Convert Dio exception to ApiException containing backend validation errors
  ApiException handleDioError(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final body = e.response!.data;
      return ApiException(
        message: body['message'] ?? 'API Error',
        messages: List<String>.from(
          body['messages'] ?? [body['message'] ?? 'An error occurred'],
        ),
      );
    }
    return ApiException(message: e.message ?? 'Network connection error');
  }
}

class ApiException implements Exception {
  final String message;
  final List<String> messages;

  ApiException({required this.message, this.messages = const []});

  @override
  String toString() => message;
}
