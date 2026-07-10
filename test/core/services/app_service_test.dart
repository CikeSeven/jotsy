import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('diaryCardTagLimitProvider', () {
    const guardTimeout = Duration(seconds: 2);

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('delivers an update triggered by the initial data emission', () async {
      final settings = await SettingsService.create();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
      );
      final emittedValues = <int>[];
      final updated = Completer<void>();
      var triggeredUpdate = false;
      ProviderSubscription<AsyncValue<int>>? subscription;

      try {
        subscription = container.listen<AsyncValue<int>>(
          diaryCardTagLimitProvider,
          (previous, next) {
            switch (next) {
              case AsyncData<int>(:final value):
                emittedValues.add(value);
                if (value == 2 && !triggeredUpdate) {
                  triggeredUpdate = true;
                  // Setter 在首次 await 前同步通知，用首个 AsyncData 回调精准复现
                  // async* 首次 yield 与后续 listener 注册之间的竞态窗口。
                  unawaited(settings.setDiaryCardTagLimit(7));
                }
                if (value == 7 && !updated.isCompleted) {
                  updated.complete();
                }
              case AsyncError<int>(:final error, :final stackTrace):
                if (!updated.isCompleted) {
                  updated.completeError(error, stackTrace);
                }
              case AsyncLoading<int>():
                break;
            }
          },
          fireImmediately: true,
        );

        await updated.future.timeout(guardTimeout);

        expect(emittedValues, <int>[2, 7]);
      } finally {
        subscription?.close();
        container.dispose();
      }
    });

    test('delivers later updates and detaches when disposed', () async {
      final settings = await SettingsService.create();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
      );
      final emittedValues = <int>[];
      final initialValue = Completer<void>();
      final updated = Completer<void>();
      ProviderSubscription<AsyncValue<int>>? subscription;

      try {
        subscription = container.listen<AsyncValue<int>>(
          diaryCardTagLimitProvider,
          (previous, next) {
            switch (next) {
              case AsyncData<int>(:final value):
                emittedValues.add(value);
                if (value == 2 && !initialValue.isCompleted) {
                  initialValue.complete();
                }
                if (value == 7 && !updated.isCompleted) {
                  updated.complete();
                }
              case AsyncError<int>(:final error, :final stackTrace):
                if (!initialValue.isCompleted) {
                  initialValue.completeError(error, stackTrace);
                }
                if (!updated.isCompleted) {
                  updated.completeError(error, stackTrace);
                }
              case AsyncLoading<int>():
                break;
            }
          },
          fireImmediately: true,
        );

        await initialValue.future.timeout(guardTimeout);
        // 退出首帧竞态窗口，确保本用例验证的是正常的后续更新链路。
        await Future<void>.delayed(Duration.zero);
        await settings.setDiaryCardTagLimit(7);
        await updated.future.timeout(guardTimeout);
        expect(emittedValues, <int>[2, 7]);

        container.dispose();

        expect(() {
          settings.diaryCardTagLimitNotifier.value = 9;
        }, returnsNormally);
        await Future<void>.delayed(Duration.zero);
        expect(emittedValues, <int>[2, 7]);
      } finally {
        subscription?.close();
        container.dispose();
      }
    });
  });
}
