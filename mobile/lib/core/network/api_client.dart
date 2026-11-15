import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
        connectTimeout: const Duration(seconds: 20),
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
          if (kDebugMode) {
            debugPrint("=== API REQUEST: ${options.path} ===");
          }
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
          sendTimeout: const Duration(seconds: 8),
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
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
          final rotatedRefresh = response.data['refresh'] as String?;
          await storageService.saveTokens(
            accessToken: newAccess,
            refreshToken: rotatedRefresh != null && rotatedRefresh.isNotEmpty
                ? rotatedRefresh
                : currentRefresh,
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

  String _handleError(DioException e) => _handleDioError(e);

  static String _handleDioError(
    DioException e, {
    String fallback = AppStrings.defaultError,
  }) {
    if (kDebugMode) {
      debugPrint('=== DIO EXCEPTION DETAILED ===');
      debugPrint('Type: ${e.type}');
      debugPrint('Message: ${e.message}');
      debugPrint('Error: ${e.error}');
      debugPrint('Response status: ${e.response?.statusCode}');
      debugPrint('Response data: ${e.response?.data}');
      debugPrint('Request URI: ${e.requestOptions.uri}');
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Le serveur met trop de temps à répondre. Veuillez réessayer.';
    }

    if (e.type == DioExceptionType.connectionError) {
      return AppStrings.networkError;
    }

    final statusCode = e.response?.statusCode;
    if (statusCode == 429) {
      return 'Trop de tentatives. Veuillez patienter un instant avant de réessayer.';
    }

    if (e.response != null) {
      final extracted = _extractMessageFromData(e.response?.data);
      if (extracted != null && extracted.isNotEmpty) {
        return extracted;
      }
      if (statusCode != null && statusCode >= 500) {
        return 'Erreur serveur temporaire ($statusCode). Veuillez réessayer.';
      }
      return fallback;
    }

    final rawErr = '${e.error ?? ''} ${e.message ?? ''}'.toLowerCase();
    if (rawErr.contains('socketexception') ||
        rawErr.contains('handshakeexception') ||
        rawErr.contains('failed host lookup')) {
      return AppStrings.networkError;
    }

    return fallback;
  }

  /// Extrait un message utilisateur lisible depuis une erreur jetée par ApiClient,
  /// DioException ou GoogleSignIn (PlatformException).
  static String formatAuthError(
    Object e, {
    String fallback = 'Erreur de connexion au serveur.',
  }) {
    if (e is String) {
      final cleaned = cleanServerMessage(e);
      if (cleaned.isNotEmpty) return cleaned;
      return fallback;
    }
    if (e is DioException) {
      return _handleDioError(e, fallback: fallback);
    }
    if (e is PlatformException) {
      final raw = '${e.code} ${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();
      if (raw.contains('network_error') || raw.contains(': 7:')) {
        return 'Connexion internet indisponible pour Google Sign-In.';
      }
      if (raw.contains('sign_in_canceled') || raw.contains('12501')) {
        return 'Connexion Google annulée.';
      }
      if (raw.contains('apiexception: 10') ||
          raw.contains(': 10:') ||
          raw.contains('developer_error') ||
          raw.contains('12500')) {
        return 'Configuration Google Sign-In invalide (certificat SHA-1 ou OAuth manquant).';
      }
      final msg = e.message?.trim();
      if (msg != null && msg.isNotEmpty) return msg;
      return fallback;
    }
    final text = cleanServerMessage(e.toString());
    if (text.startsWith('Exception: ')) {
      final body = text.substring('Exception: '.length).trim();
      if (body.isNotEmpty) return body;
    }
    return fallback;
  }

  static String? _extractMessageFromData(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      if (data['error'] is Map) {
        final errMap = data['error'] as Map;
        final nested = _flattenValue(
          errMap['message'] ?? errMap['detail'] ?? errMap.values.firstOrNull,
        );
        if (nested != null && nested.isNotEmpty) return nested;
      } else if (data['error'] != null) {
        final errText = _flattenValue(data['error']);
        if (errText != null && errText.isNotEmpty) return errText;
      }
      if (data['non_field_errors'] != null) {
        final nonField = _flattenValue(data['non_field_errors']);
        if (nonField != null && nonField.isNotEmpty) return nonField;
      }
      if (data['detail'] != null) {
        final detail = _flattenValue(data['detail']);
        if (detail != null && detail.isNotEmpty) return detail;
      }
      final parts = <String>[];
      for (final value in data.values) {
        final text = _flattenValue(value);
        if (text != null && text.isNotEmpty) parts.add(text);
      }
      if (parts.isNotEmpty) return parts.join('\n');
      return null;
    }
    return _flattenValue(data);
  }

  static String? _flattenValue(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final parts = value
          .map((item) => _flattenValue(item))
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      return parts.isEmpty ? null : parts.join(' ');
    }
    if (value is Map) {
      return _extractMessageFromData(value);
    }
    final raw = value.toString().trim();
    if (raw.isEmpty || raw.startsWith('<')) return null;
    return cleanServerMessage(raw);
  }

  static String cleanServerMessage(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    final errorDetailRegex = RegExp(
      r'''ErrorDetail\(string=(?:'([^']*)'|"([^"]*)"),\s*code=[^\)]+\)''',
    );
    if (errorDetailRegex.hasMatch(text)) {
      final extracted = errorDetailRegex
          .allMatches(text)
          .map((m) => (m.group(1) ?? m.group(2) ?? '').trim())
          .where((s) => s.isNotEmpty)
          .join(' ');
      if (extracted.isNotEmpty) {
        text = extracted;
      }
    }

    if (text.startsWith('detail: ')) {
      text = text.substring('detail: '.length).trim();
    }
    if (text.startsWith('[') && text.endsWith(']') && text.length > 2) {
      text = text.substring(1, text.length - 1).trim();
    }
    return text;
  }
}
