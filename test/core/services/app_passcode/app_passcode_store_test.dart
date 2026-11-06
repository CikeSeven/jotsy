import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_passcode/app_passcode_store.dart';
import 'package:node_diary/core/services/backup_settings.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_passcode_test_support.dart';

Future<AppPasscodeStore> _store(TestClock clock) =>
    AppPasscodeStore.create(hasher: testPasscodeHasher, clock: clock.call);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('AppPasscodeConfig', () {
    test('round-trips a PIN and a pattern through JSON', () async {
      final secret = await testPasscodeHasher.create('pin:1234');
      final pin = AppPasscodeConfig(
        secret: secret,
        pinLength: 4,
        biometric: true,
        failedCount: 3,
        lockedUntil: DateTime(2026, 11, 6, 9, 30),
      );
      expect(AppPasscodeConfig.decode(pin.encode()), pin);
      final pattern = AppPasscodeConfig(
        secret: secret,
        kind: AppPasscodeKind.pattern,
      );
      final decoded = AppPasscodeConfig.decode(pattern.encode());
      expect(decoded.kind, AppPasscodeKind.pattern);
      expect(decoded.method, AppVerificationMethod.passcode);
    });

    test('anything unreadable falls back to system verification', () {
      expect(AppPasscodeConfig.decode(null).hasPasscode, isFalse);
      expect(AppPasscodeConfig.decode('not json').hasPasscode, isFalse);
      expect(AppPasscodeConfig.decode('[]').hasPasscode, isFalse);
      final base = <String, Object?>{
        'kind': 'pin',
        'length': 6,
        'hash': base64Encode(<int>[1, 2]),
        'salt': base64Encode(<int>[3]),
        'iter': 10,
      };
      expect(AppPasscodeConfig.decode(jsonEncode(base)).hasPasscode, isTrue);
      // 形式未知、位数不合法、摘要缺失：都不画一个对不上的输入界面。
      for (final broken in <Map<String, Object?>>[
        <String, Object?>{...base, 'kind': 'password'},
        <String, Object?>{...base, 'length': 5},
        <String, Object?>{...base, 'hash': null},
        <String, Object?>{...base, 'iter': 0},
      ]) {
        expect(
          AppPasscodeConfig.decode(jsonEncode(broken)).method,
          AppVerificationMethod.system,
          reason: '$broken',
        );
      }
      // 其余字段坏了取默认值。
      final lenient = AppPasscodeConfig.decode(
        jsonEncode(<String, Object?>{
          ...base,
          'biometric': 'yes',
          'failed': -2,
          'lockedUntil': 'soon',
        }),
      );
      expect(lenient.biometric, isFalse);
      expect(lenient.failedCount, 0);
      expect(lenient.lockedUntil, isNull);
    });

    test('rules accept only real PINs and patterns', () {
      expect(AppPasscodeRules.validPin('0428', 4), isTrue);
      expect(AppPasscodeRules.validPin('042', 4), isFalse);
      expect(AppPasscodeRules.validPin('04a8', 4), isFalse);
      expect(AppPasscodeRules.validPin('12345', 5), isFalse);
      expect(AppPasscodeRules.validPattern(<int>[0, 1, 2, 5]), isTrue);
      expect(AppPasscodeRules.validPattern(<int>[0, 1, 2]), isFalse);
      expect(AppPasscodeRules.validPattern(<int>[0, 1, 1, 2]), isFalse);
      expect(AppPasscodeRules.validPattern(<int>[0, 1, 2, 9]), isFalse);
    });
  });

  group('AppPasscodeStore', () {
    test('a PIN is checked and kept only on this device key', () async {
      final store = await _store(TestClock());
      expect(store.config.method, AppVerificationMethod.system);
      await store.setPin('120428', biometric: true);
      expect(store.config.kind, AppPasscodeKind.pin);
      expect(store.config.pinLength, 6);
      expect(store.config.biometric, isTrue);
      expect(
        (await store.verify('120428')).status,
        AppPasscodeCheckStatus.accepted,
      );
      final wrong = await store.verify('120429');
      expect(wrong.status, AppPasscodeCheckStatus.wrong);
      expect(wrong.attemptsLeft, 4);

      // 重新打开存储（杀进程）：密码与输错次数都还在。
      final reopened = await _store(TestClock());
      expect(reopened.config.hasPasscode, isTrue);
      expect(reopened.config.failedCount, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppPasscodeStore.key), isNotNull);
      expect(prefs.getString(AppPasscodeStore.key), isNot(contains('120428')));
    });

    test('a pattern is checked by its dots in order', () async {
      final store = await _store(TestClock());
      await store.setPattern(<int>[0, 4, 8, 5]);
      expect(store.config.kind, AppPasscodeKind.pattern);
      expect(
        (await store.verify('0-4-8-5')).status,
        AppPasscodeCheckStatus.accepted,
      );
      expect(
        (await store.verify('5-8-4-0')).status,
        AppPasscodeCheckStatus.wrong,
      );
    });

    test('the same digits as a different form do not match', () async {
      final store = await _store(TestClock());
      await store.setPattern(<int>[1, 2, 3, 4]);
      expect((await store.verify('1234')).status, AppPasscodeCheckStatus.wrong);
    });

    test(
      'lockout grows from the fifth failure and survives restarts',
      () async {
        final clock = TestClock();
        final store = await _store(clock);
        await store.setPin('1111');
        for (var i = 0; i < 4; i++) {
          expect(
            (await store.verify('0000')).status,
            AppPasscodeCheckStatus.wrong,
          );
        }
        final fifth = await store.verify('0000');
        expect(fifth.status, AppPasscodeCheckStatus.lockedOut);
        expect(fifth.lockedUntil, clock.now.add(const Duration(seconds: 30)));
        // 等待中连对的也不核对。
        expect(
          (await store.verify('1111')).status,
          AppPasscodeCheckStatus.lockedOut,
        );
        expect(await (await _store(clock)).currentLockout(), isNotNull);

        clock.now = clock.now.add(const Duration(seconds: 31));
        final sixth = await store.verify('0000');
        expect(sixth.lockedUntil, clock.now.add(const Duration(minutes: 1)));
        clock.now = clock.now.add(const Duration(minutes: 2));
        expect(
          (await store.verify('1111')).status,
          AppPasscodeCheckStatus.accepted,
        );
        expect(store.config.failedCount, 0);
        expect(store.config.lockedUntil, isNull);
      },
    );

    test('a clock turned back cannot stretch the wait', () async {
      final clock = TestClock();
      final store = await _store(clock);
      await store.setPin('1111');
      for (var i = 0; i < 5; i++) {
        await store.verify('0000');
      }
      clock.now = clock.now.subtract(const Duration(days: 3));
      final until = await store.currentLockout();
      expect(until, clock.now.add(const Duration(seconds: 30)));
    });

    test('clearing returns to system verification', () async {
      final store = await _store(TestClock());
      await store.setPin('1111');
      await store.clear();
      expect(store.config.method, AppVerificationMethod.system);
      expect(
        (await store.verify('1111')).status,
        AppPasscodeCheckStatus.noPasscode,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(AppPasscodeStore.key), isFalse);
    });

    test('backups carry the app lock switch but never the passcode', () async {
      SharedPreferences.setMockInitialValues(
        await presetPin('2580', appLock: true),
      );
      final settings = await SettingsService.create();
      final captured = jsonEncode(BackupSettings.capture(settings));
      expect(captured, contains('"appLockEnabled":true'));
      final stored = (await SharedPreferences.getInstance()).getString(
        AppPasscodeStore.key,
      )!;
      final hash =
          (jsonDecode(stored) as Map<String, Object?>)['hash']! as String;
      expect(captured, isNot(contains(hash)));
      expect(captured, isNot(contains(AppPasscodeStore.key)));
    });

    test('changing the passcode keeps the fingerprint switch', () async {
      final store = await _store(TestClock());
      await store.setPin('1111', biometric: true);
      await store.verify('0000');
      await store.setPattern(<int>[2, 4, 6, 7]);
      expect(store.config.biometric, isTrue);
      expect(store.config.failedCount, 0);
      await store.setBiometric(false);
      expect(store.config.biometric, isFalse);
    });
  });
}
