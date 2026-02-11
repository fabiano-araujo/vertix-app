import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import '../utils/logger.dart';

/// API Client for VERTIX
/// Handles all HTTP requests with authentication
class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal() {
    Logger.i(Logger.tagApi, 'Inicializando ApiClient: ${ApiConstants.baseUrl}');

    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectionTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          Logger.request(
            options.method,
            '${options.baseUrl}${options.path}',
            options.data,
          );

          return handler.next(options);
        },
        onResponse: (response, handler) {
          Logger.response(
            response.statusCode ?? 200,
            response.requestOptions.path,
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          Logger.response(
            error.response?.statusCode ?? 0,
            error.requestOptions.path,
            error.response?.data,
          );

          // Handle 401 - token expired
          if (error.response?.statusCode == 401) {
            Logger.w(Logger.tagApi, 'Token expirado ou invalido');
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Set auth token
  Future<void> setToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  /// Clear auth token
  Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null;
  }

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
