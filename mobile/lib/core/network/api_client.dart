import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../constants/app_strings.dart';
import '../storage/storage_service.dart';

class ApiClient {
  late final Dio _dio;
  final StorageService storageService;

  ApiClient({required this.storageService}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = storageService.accessToken;
          print("=== API REQUEST: ${options.path} ===");
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            if (storageService.refreshToken != null && storageService.refreshToken!.isNotEmpty) {
              final refreshed = await _tryRefreshToken();
              if (refreshed) {
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer ${storageService.accessToken}';
                try {
                  final cloneReq = await _dio.fetch(opts);
                  return handler.resolve(cloneReq);
                } catch (_) {}
              } else {
                await storageService.clearSession();
              }
            } else {
              await storageService.clearSession();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    if (storageService.refreshToken == null || storageService.refreshToken!.isEmpty) {
      return false; // No refresh token available, cannot refresh
    }

    try {
      final response = await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.refresh}',
        data: {'refresh': storageService.refreshToken},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500, // Handle 4xx errors without throwing immediately
        ),
      );

      if (response.statusCode == 200) {
        final newAccess = response.data['access'] as String?;
        if (newAccess != null && newAccess.isNotEmpty) {
          final currentRefresh = storageService.refreshToken ?? '';
          await storageService.saveTokens(
            accessToken: newAccess,
            refreshToken: currentRefresh,
          );
          return true;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 400) {
        // Only clear session if the refresh token itself is rejected or invalid
        await storageService.clearSession();
      }
    } catch (_) {
      // On network error or other exceptions, do not clear the session.
      // The user might just be offline.
    }
    return false;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    print('=== DIO EXCEPTION DETAILED ===');
    print('Type: ${e.type}');
    print('Message: ${e.message}');
    print('Error: ${e.error}');
    print('Response status: ${e.response?.statusCode}');
    print('Response data: ${e.response?.data}');
    print('Request URI: ${e.requestOptions.uri}');
    
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return AppStrings.networkError;
    }

    if (e.response != null && e.response?.data is Map) {
      final data = e.response?.data as Map;
      if (data.containsKey('error') && data['error'] is Map) {
        final msg = data['error']['message'];
        if (msg != null && msg.toString().isNotEmpty) {
          return msg.toString();
        }
      }
    }

    return AppStrings.defaultError;
  }
}
