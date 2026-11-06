import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_password/app_password_hasher.dart';
import 'package:node_diary/core/services/app_password/app_password_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const AppPasswordHasher _fastHasher = AppPasswordHasher(
  iterations: 64,
  useIsolate: false,
);

class _Clock {
  DateTime now = DateTime(2026, 11, 6, 9);
  DateTime call() => now;
}

Future<AppPasswordStore> _store(_Clock clock) =>
    AppPasswordStore.create(hasher: _fastHasher, clock: clock.call);

void main() {
  group('AppPasswordHasher', () {
    test('matches the original password and nothing else', () async {
      final secret = await _fastHasher.create('Diary2026');
      expect(secret.salt, hasLength(AppPasswordHasher.saltBytes));
      expect(secret.iterations, 64);
      expect(await _fastHasher.matches('Diary2026', secret), isTrue);
      expect(await _fastHasher.matches('diary2026', secret), isFalse);
      expect(await _fastHasher.matches('Diary202', secret), isFalse);
    });

    test('uses a fresh salt for every password', () async {
      final a = await _fastHasher.create('same');
      final b = await _fastHasher.create('same');
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
    });

    test('verifies with the iterations stored alongside the hash', () async {
      final old = await const AppPasswordHasher(
        iterations: 32,
        useIsolate: false,
      ).create('pass1');
      expect(await _fastHasher.matches('pass1', old), isTrue);
    });
  });

  group('AppPasswordRules', () {
    test('accepts 4 to 16 characters without whitespace', () {
      expect(AppPasswordRules.check('abc'), AppPasswordProblem.tooShort);
      expect(AppPasswordRules.check('ab1D'), isNull);
      expect(AppPasswordRules.check('a' * 16), isNull);
      expect(AppPasswordRules.check('a' * 17), AppPasswordProblem.tooLong);
      expect(AppPasswordRules.check('ab cd'), AppPasswordProblem.whitespace);
      expect(AppPasswordRules.check('日记密码'), isNull);
    });
  });

  group('AppPasswordConfig', () {
    test('round-trips through JSON', () async {
      final secret = await _fastHasher.create('abcd');
      final config = AppPasswordConfig(
        secret: secret,
        biometric: true,
        failedCount: 5,
        lockedUntil: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(AppPasswordConfig.decode(config.encode()), config);
      expect(config.method, AppVerificationMethod.password);
    });

    test('falls back to system verification when the hash is unusable', () {
      for (final raw in <String?>[
        null,
        '',
        'not json',
        '[]',
        '{"hash":"","salt":"AAAA","iter":10}',
        '{"hash":"AAAA","salt":"AAAA","iter":0}',
        '{"hash":"%%%","salt":"AAAA","iter":10}',
      ]) {
        final config = AppPasswordConfig.decode(raw);
        expect(config.hasPassword, isFalse, reason: '$raw');
        expect(config.method, AppVerificationMethod.system);
      }
    });

    test('tolerates bad optional fields', () {
      final config = AppPasswordConfig.decode(
        '{"hash":"AAAA","salt":"AAAA","iter":10,'
        '"biometric":"yes","failed":-3,"lockedUntil":"soon"}',
      );
      expect(config.hasPassword, isTrue);
      expect(config.biometric, isFalse);
      expect(config.failedCount, 0);
      expect(config.lockedUntil, isNull);
    });

    test('encodes nothing without a password', () {
      expect(AppPasswordConfig.initial.encode(), isNull);
    });
  });

  group('AppPasswordStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('sets, verifies and clears the password', () async {
      final clock = _Clock();
      final store = await _store(clock);
      expect(store.config.method, AppVerificationMethod.system);

      await store.setPassword('Secret1', biometric: true);
      expect(store.config.method, AppVerificationMethod.password);
      expect(store.config.biometric, isTrue);
      expect(
        (await store.verify('Secret1')).status,
        AppPasswordCheckStatus.accepted,
      );

      await store.clearPassword();
      expect(store.config, AppPasswordConfig.initial);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppPasswordStore.key), isNull);
      expect(
        (await store.verify('Secret1')).status,
        AppPasswordCheckStatus.noPassword,
      );
    });

    test('changing the password keeps the biometric choice', () async {
      final store = await _store(_Clock());
      await store.setPassword('first', biometric: false);
      await store.setPassword('second');
      expect(store.config.biometric, isFalse);
      expect(
        (await store.verify('first')).status,
        AppPasswordCheckStatus.wrong,
      );
      expect(
        (await store.verify('second')).status,
        AppPasswordCheckStatus.accepted,
      );
    });

    test('locks out after repeated mistakes with growing waits', () async {
      final clock = _Clock();
      final store = await _store(clock);
      await store.setPassword('right');

      for (var left = 4; left >= 1; left--) {
        final check = await store.verify('wrong');
        expect(check.status, AppPasswordCheckStatus.wrong);
        expect(check.attemptsLeft, left);
      }
      final fifth = await store.verify('wrong');
      expect(fifth.status, AppPasswordCheckStatus.lockedOut);
      expect(fifth.lockedUntil, clock.now.add(const Duration(seconds: 30)));

      // 等待期间连正确的密码也不核对。
      clock.now = clock.now.add(const Duration(seconds: 10));
      final blocked = await store.verify('right');
      expect(blocked.status, AppPasswordCheckStatus.lockedOut);

      clock.now = clock.now.add(const Duration(seconds: 20));
      expect(await store.currentLockout(), isNull);
      final sixth = await store.verify('wrong');
      expect(sixth.lockedUntil, clock.now.add(const Duration(minutes: 1)));

      clock.now = clock.now.add(const Duration(minutes: 1));
      final seventh = await store.verify('wrong');
      expect(seventh.lockedUntil, clock.now.add(const Duration(minutes: 5)));

      clock.now = clock.now.add(const Duration(minutes: 5));
      final eighth = await store.verify('wrong');
      expect(eighth.lockedUntil, clock.now.add(const Duration(minutes: 15)));

      clock.now = clock.now.add(const Duration(minutes: 15));
      expect(
        (await store.verify('right')).status,
        AppPasswordCheckStatus.accepted,
      );
      expect(store.config.failedCount, 0);
      expect(store.config.lockedUntil, isNull);
    });

    test('keeps the lockout across restarts', () async {
      final clock = _Clock();
      final store = await _store(clock);
      await store.setPassword('right');
      for (var i = 0; i < 5; i++) {
        await store.verify('nope');
      }
      final reopened = await _store(clock);
      expect(reopened.config.failedCount, 5);
      expect(
        await reopened.currentLockout(),
        clock.now.add(const Duration(seconds: 30)),
      );
    });

    test('caps a lockout stretched by turning the clock back', () async {
      final clock = _Clock();
      final store = await _store(clock);
      await store.setPassword('right');
      for (var i = 0; i < 5; i++) {
        await store.verify('nope');
      }
      clock.now = clock.now.subtract(const Duration(days: 3));
      final capped = await store.currentLockout();
      expect(capped, clock.now.add(const Duration(seconds: 30)));
      expect(store.config.lockedUntil, capped);
    });

    test('a biometric unlock clears the mistakes', () async {
      final store = await _store(_Clock());
      await store.setPassword('right');
      for (var i = 0; i < 5; i++) {
        await store.verify('nope');
      }
      await store.resetFailures();
      expect(store.config.failedCount, 0);
      expect(await store.currentLockout(), isNull);
    });

    test('concurrent checks each count once', () async {
      final store = await _store(_Clock());
      await store.setPassword('right');
      await Future.wait(<Future<AppPasswordCheck>>[
        store.verify('a'),
        store.verify('b'),
        store.verify('c'),
      ]);
      expect(store.config.failedCount, 3);
    });
  });
}
