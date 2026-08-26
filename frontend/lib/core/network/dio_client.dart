import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/constants.dart';
import '../storage/storage_service.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return DioClient(storage, ref);
});

class DioClient {
  final StorageService _storage;
  final Ref _ref;
  late final Dio _dio;

  Dio get dio => _dio;

  DioClient(this._storage, this._ref) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseApiUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Check if error is 401 Unauthorized
          if (error.response?.statusCode == 401) {
            final refreshToken = _storage.getRefreshToken();
            if (refreshToken != null) {
              try {
                // Attempt to refresh token
                final newTokens = await _refreshToken(refreshToken);
                if (newTokens != null) {
                  // Save tokens
                  await _storage.setAccessToken(newTokens['access_token']!);
                  await _storage.setRefreshToken(newTokens['refresh_token']!);
                  
                  // Retry the original request
                  final options = error.requestOptions;
                  options.headers['Authorization'] = 'Bearer ${newTokens['access_token']}';
                  
                  final response = await _dio.request(
                    options.path,
                    options: Options(
                      method: options.method,
                      headers: options.headers,
                    ),
                    data: options.data,
                    queryParameters: options.queryParameters,
                  );
                  return handler.resolve(response);
                }
              } catch (e) {
                // Refresh failed
                await _storage.clearAuth();
                // We'll let the routing state catch the null token and redirect to login
              }
            } else {
              await _storage.clearAuth();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<Map<String, String>?> _refreshToken(String token) async {
    try {
      final response = await Dio().post(
        '${AppConstants.baseApiUrl}/api/auth/refresh',
        queryParameters: {'refresh_token': token},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'access_token': data['access_token'] as String,
          'refresh_token': data['refresh_token'] as String,
        };
      }
    } catch (e) {
      // Error refreshing token
    }
    return null;
  }
}
