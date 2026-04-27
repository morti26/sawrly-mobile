import 'package:dio/dio.dart';
import '../auth/token_storage.dart';

class ApiClient {
  // Use local network IP for real device, 10.0.2.2 for Android Emulator
  static const String baseUrl = 'https://ph.sitely24.com/api';

  final Dio _dio;
  final TokenStorage _tokenStorage;
  Future<void> Function()? _onUnauthorized;
  bool _isHandlingUnauthorized = false;

  ApiClient(this._tokenStorage)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        final requestPath = e.requestOptions.path;
        final hasAuthHeader = e.requestOptions.headers['Authorization'] != null;
        final isAuthRequest = requestPath.contains('/auth/login') ||
            requestPath.contains('/auth/register');

        if (e.response?.statusCode == 401 &&
            hasAuthHeader &&
            !isAuthRequest &&
            !_isHandlingUnauthorized) {
          _isHandlingUnauthorized = true;
          try {
            if (_onUnauthorized != null) {
              await _onUnauthorized!.call();
            } else {
              await _tokenStorage.clear();
            }
          } finally {
            _isHandlingUnauthorized = false;
          }
        }
        return handler.next(e);
      },
    ));
  }

  void setUnauthorizedHandler(Future<void> Function() handler) {
    _onUnauthorized = handler;
  }

  Dio get client => _dio;
}
