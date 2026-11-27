import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';

void main() {
  group('BandBbsToken.fromTokenResponse', () {
    test('rejects responses without a usable access token', () {
      expect(
        () => BandBbsToken.fromTokenResponse({
          'access_token': '',
          'expires_in': 3600,
        }),
        throwsFormatException,
      );
    });

    test('rejects already expired responses', () {
      expect(
        () => BandBbsToken.fromTokenResponse({
          'access_token': 'token',
          'expires_in': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('OronBoxSession.fromTokenResponse', () {
    test('requires both access and refresh tokens', () {
      expect(
        () => OronBoxSession.fromTokenResponse({
          'access_token': 'access',
          'refresh_token': '',
          'expires_in': 3600,
        }),
        throwsFormatException,
      );
    });

    test('accepts a complete session response', () {
      final session = OronBoxSession.fromTokenResponse({
        'access_token': ' access ',
        'refresh_token': ' refresh ',
        'expires_in': 3600,
      });

      expect(session.accessToken, 'access');
      expect(session.refreshToken, 'refresh');
      expect(session.isExpired, isFalse);
    });
  });
}
