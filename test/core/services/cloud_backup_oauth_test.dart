import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_oauth.dart';

void main() {
  group('CloudPkce', () {
    test('derives the RFC 7636 appendix B challenge', () {
      final pkce = CloudPkce.fromVerifier(
        'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
      );
      expect(pkce.challenge, 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    });

    test('generates a 43-char unpadded base64url verifier', () {
      final pkce = CloudPkce.generate();
      expect(pkce.verifier, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(CloudPkce.fromVerifier(pkce.verifier).challenge, pkce.challenge);
    });
  });

  group('CloudOAuthToken', () {
    test('keeps the previous refresh token when a refresh omits it', () {
      final now = DateTime.utc(2026, 10, 16, 8);
      final token = CloudOAuthToken.fromResponse(
        {'access_token': 'a2', 'expires_in': '3600'},
        previousRefreshToken: 'r1',
        now: now,
      );
      expect(token.refreshToken, 'r1');
      expect(token.expiresAt, now.add(const Duration(hours: 1)));
      // 提前两分钟视为需要刷新。
      expect(token.needsRefresh(now.add(const Duration(minutes: 57))), isFalse);
      expect(token.needsRefresh(now.add(const Duration(minutes: 58))), isTrue);
    });

    test('round-trips through config JSON and rejects a missing token', () {
      final credentials = CloudDriveCredentials(
        token: CloudOAuthToken(
          accessToken: 'a',
          refreshToken: 'r',
          expiresAt: DateTime.utc(2026),
        ),
        account: 'me@example.com',
      );
      final parsed = CloudDriveCredentials.fromConfig(credentials.toConfig());
      expect(parsed.token.accessToken, 'a');
      expect(parsed.token.refreshToken, 'r');
      expect(parsed.token.expiresAt, DateTime.utc(2026));
      expect(parsed.account, 'me@example.com');
      expect(
        () => CloudDriveCredentials.fromConfig(const {'account': 'x'}),
        throwsA(
          isA<CloudBackupException>().having(
            (e) => e.failure,
            'failure',
            CloudBackupFailure.sessionExpired,
          ),
        ),
      );
    });

    test('a response without access_token is a protocol failure', () {
      expect(
        () => CloudOAuthToken.fromResponse(const {'token_type': 'bearer'}),
        throwsA(isA<CloudBackupException>()),
      );
    });
  });

  group('CloudDeviceAuthorization', () {
    test('reads Google verification_url and Microsoft verification_uri', () {
      final now = DateTime.utc(2026);
      final google = CloudDeviceAuthorization.fromResponse({
        'device_code': 'd',
        'user_code': 'ABCD-EFGH',
        'verification_url': 'https://www.google.com/device',
        'expires_in': 1800,
        'interval': 5,
      }, now: now);
      expect(google.verificationUri.host, 'www.google.com');
      expect(google.expiresAt, now.add(const Duration(minutes: 30)));
      final microsoft = CloudDeviceAuthorization.fromResponse({
        'device_code': 'd',
        'user_code': 'XYZ',
        'verification_uri': 'https://microsoft.com/devicelogin',
        'verification_uri_complete': 'https://microsoft.com/devicelogin?c=XYZ',
      });
      expect(microsoft.verificationUriComplete?.query, 'c=XYZ');
      expect(microsoft.interval, const Duration(seconds: 5));
    });
  });

  group('waitForDeviceToken', () {
    CloudDeviceAuthorization authorization(DateTime expiresAt) =>
        CloudDeviceAuthorization(
          deviceCode: 'd',
          userCode: 'u',
          verificationUri: Uri.parse('https://example.com/device'),
          expiresAt: expiresAt,
          interval: const Duration(seconds: 5),
        );

    test(
      'keeps polling through pending, slows down, then returns the token',
      () async {
        final waits = <Duration>[];
        final results = <CloudDevicePoll>[
          const CloudDevicePending(),
          const CloudDeviceSlowDown(),
          const CloudDevicePending(),
          const CloudDeviceGranted(CloudOAuthToken(accessToken: 'ok')),
        ];
        final token = await waitForDeviceToken(
          authorization(DateTime.now().add(const Duration(hours: 1))),
          (_) async => results.removeAt(0),
          cancellation: CloudBackupCancellation(),
          delay: (duration) async => waits.add(duration),
        );
        expect(token.accessToken, 'ok');
        // slow_down 之后间隔加 5 秒并保持。
        expect(waits.map((d) => d.inSeconds), [5, 5, 10, 10]);
      },
    );

    test('tolerates two network blips but gives up on the third', () async {
      var calls = 0;
      final token = await waitForDeviceToken(
        authorization(DateTime.now().add(const Duration(hours: 1))),
        (_) async {
          calls++;
          if (calls <= 2) {
            throw const CloudBackupException(CloudBackupFailure.network);
          }
          return const CloudDeviceGranted(CloudOAuthToken(accessToken: 'ok'));
        },
        cancellation: CloudBackupCancellation(),
        delay: (_) async {},
      );
      expect(token.accessToken, 'ok');

      await expectLater(
        waitForDeviceToken(
          authorization(DateTime.now().add(const Duration(hours: 1))),
          (_) async =>
              throw const CloudBackupException(CloudBackupFailure.network),
          cancellation: CloudBackupCancellation(),
          delay: (_) async {},
        ),
        throwsA(isA<CloudBackupException>()),
      );
    });

    test('stops with authorizationExpired once the code has expired', () async {
      var polled = false;
      await expectLater(
        waitForDeviceToken(
          authorization(DateTime.now().subtract(const Duration(seconds: 1))),
          (_) async {
            polled = true;
            return const CloudDevicePending();
          },
          cancellation: CloudBackupCancellation(),
          delay: (_) async {},
        ),
        throwsA(
          isA<CloudBackupException>().having(
            (e) => e.failure,
            'failure',
            CloudBackupFailure.authorizationExpired,
          ),
        ),
      );
      expect(polled, isFalse);
    });

    test('cancellation interrupts the wait without polling again', () async {
      final cancellation = CloudBackupCancellation();
      var polls = 0;
      final waiting = waitForDeviceToken(
        authorization(DateTime.now().add(const Duration(hours: 1))),
        (_) async {
          polls++;
          return const CloudDevicePending();
        },
        cancellation: cancellation,
        // 永不结束的等待：只有取消能打断。
        delay: (_) => Completer<void>().future,
      );
      cancellation.cancel();
      await expectLater(waiting, throwsA(isA<CloudBackupCancelled>()));
      expect(polls, 0);
    });

    test('classifies device poll errors', () {
      expect(
        classifyDevicePollError('authorization_pending', 428),
        isA<CloudDevicePending>(),
      );
      expect(
        classifyDevicePollError('slow_down', 403),
        isA<CloudDeviceSlowDown>(),
      );
      for (final (error, failure) in [
        ('access_denied', CloudBackupFailure.authorizationDenied),
        ('authorization_declined', CloudBackupFailure.authorizationDenied),
        ('expired_token', CloudBackupFailure.authorizationExpired),
        ('invalid_grant', CloudBackupFailure.authorizationExpired),
        ('something_else', CloudBackupFailure.protocol),
      ]) {
        expect(
          () => classifyDevicePollError(error, 400),
          throwsA(
            isA<CloudBackupException>().having(
              (e) => e.failure,
              'failure',
              failure,
            ),
          ),
          reason: error,
        );
      }
    });
  });

  group('CloudOAuthSession', () {
    test('refreshes an expiring token once for concurrent callers', () async {
      var refreshes = 0;
      final persisted = <CloudOAuthToken>[];
      final gate = Completer<void>();
      final session = CloudOAuthSession(
        token: CloudOAuthToken(
          accessToken: 'old',
          refreshToken: 'r1',
          expiresAt: DateTime.now().add(const Duration(seconds: 30)),
        ),
        refresh: (token) async {
          refreshes++;
          await gate.future;
          return CloudOAuthToken(
            accessToken: 'new',
            refreshToken: 'r2',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          );
        },
        onRefreshed: (token) async => persisted.add(token),
      );
      final first = session.accessToken();
      final second = session.accessToken();
      gate.complete();
      expect(await Future.wait([first, second]), ['new', 'new']);
      expect(refreshes, 1);
      expect(persisted.single.refreshToken, 'r2');
      expect(await session.accessToken(), 'new');
    });

    test(
      'refreshes after a rejection only if nobody refreshed meanwhile',
      () async {
        var refreshes = 0;
        final session = CloudOAuthSession(
          token: const CloudOAuthToken(accessToken: 'a1', refreshToken: 'r1'),
          refresh: (token) async {
            refreshes++;
            return CloudOAuthToken(accessToken: 'a${refreshes + 1}');
          },
        );
        expect(await session.refreshAfterRejection('a1'), 'a2');
        // 另一个请求带着旧令牌被拒：直接用已刷新的令牌，不再刷新。
        expect(await session.refreshAfterRejection('a1'), 'a2');
        expect(refreshes, 1);
      },
    );

    test(
      'without a refresh token a rejection means the session expired',
      () async {
        final session = CloudOAuthSession(
          token: const CloudOAuthToken(accessToken: 'a1'),
          refresh: (_) async => fail('must not refresh'),
        );
        await expectLater(
          session.refreshAfterRejection('a1'),
          throwsA(
            isA<CloudBackupException>().having(
              (e) => e.failure,
              'failure',
              CloudBackupFailure.sessionExpired,
            ),
          ),
        );
      },
    );
  });
}
