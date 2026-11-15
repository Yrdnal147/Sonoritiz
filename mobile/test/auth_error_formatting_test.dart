import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonoritiz/core/constants/app_strings.dart';
import 'package:sonoritiz/core/network/api_client.dart';

void main() {
  group('ApiClient.formatAuthError', () {
    test('cleans raw Django ErrorDetail string thrown by ApiClient', () {
      const raw = "[ErrorDetail(string='Identifiants invalides.', code='invalid')]";
      expect(
        ApiClient.formatAuthError(raw),
        equals('Identifiants invalides.'),
      );
    });

    test('preserves readable server error message strings', () {
      expect(
        ApiClient.formatAuthError('Token Google destiné à une autre application.'),
        equals('Token Google destiné à une autre application.'),
      );
    });

    test('extracts nested error.message from DioException response payload', () {
      final req = RequestOptions(path: '/api/auth/login/');
      final dioErr = DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: req,
          statusCode: 400,
          data: {
            'error': {
              'code': 'BAD_REQUEST',
              'message': 'Un utilisateur avec cet e-mail existe déjà.',
            },
          },
        ),
      );

      expect(
        ApiClient.formatAuthError(dioErr),
        equals('Un utilisateur avec cet e-mail existe déjà.'),
      );
    });

    test('translates network DioException and Google PlatformException cleanly', () {
      final req = RequestOptions(path: '/api/auth/login/');
      final netErr = DioException(
        requestOptions: req,
        type: DioExceptionType.connectionError,
      );
      expect(ApiClient.formatAuthError(netErr), equals(AppStrings.networkError));

      final shaErr = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 10: ',
      );
      expect(
        ApiClient.formatAuthError(shaErr),
        contains('SHA-1'),
      );
    });
  });
}
