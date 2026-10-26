import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/app_update_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/controllers/app_update_auto_check.dart';
import 'package:node_diary/ui/settings/controllers/app_update_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_app_update_service.dart';

/// 与首页相同的接法：创建时启动，销毁时释放。
class _Home extends ConsumerStatefulWidget {
  const _Home();

  @override
  ConsumerState<_Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<_Home> {
  late final AppUpdateAutoChecker _checker = AppUpdateAutoChecker(() async {
    if (mounted) {
      await runAutoUpdateCheck(context, ref);
    }
  });

  @override
  void initState() {
    super.initState();
    _checker.start();
  }

  @override
  void dispose() {
    _checker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}

void main() {
  late FakeAppUpdateService service;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 10, 20, 9);
    service = FakeAppUpdateService()
      ..outcome = AppUpdateCheckOutcome(fakeRelease(), AppUpdateSource.direct);
  });

  Future<void> pumpHome(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = (await tester.runAsync(SettingsService.create))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
          appUpdateServiceProvider.overrideWithValue(service),
          appUpdateClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _Home(),
        ),
      ),
    );
  }

  /// 按系统的顺序切到后台再回到前台（生命周期只允许相邻状态切换）。
  void background(WidgetTester tester) {
    for (final state in const <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  void foreground(WidgetTester tester) {
    for (final state in const <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  testWidgets(
    'checks after launch, again on return after two hours, prompting once',
    (tester) async {
      await pumpHome(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(service.fetchCount, 0, reason: 'waits for the launch delay');

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(service.fetchCount, 1);
      expect(find.text('立即更新'), findsOneWidget);
      await tester.tap(find.text('以后再说'));
      await tester.pumpAndSettle();

      // 不到两小时回到前台：不请求。
      now = now.add(const Duration(minutes: 30));
      background(tester);
      foreground(tester);
      await tester.pump(AppUpdateAutoChecker.resumeDelay);
      await tester.pumpAndSettle();
      expect(service.fetchCount, 1);

      // 满两小时回到前台：再检查，但同一版本不再弹出。
      now = now.add(const Duration(hours: 2));
      background(tester);
      foreground(tester);
      await tester.pump(AppUpdateAutoChecker.resumeDelay);
      await tester.pumpAndSettle();
      expect(service.fetchCount, 2);
      expect(find.text('立即更新'), findsNothing);
    },
  );

  testWidgets('does not check while the app is in the background', (
    tester,
  ) async {
    await pumpHome(tester);
    background(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(service.fetchCount, 0);

    foreground(tester);
    await tester.pump(AppUpdateAutoChecker.resumeDelay);
    await tester.pumpAndSettle();
    expect(service.fetchCount, 1);
  });

  testWidgets(
    'desktop prompts with a browser download that opens the package',
    (tester) async {
      final launched = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      service
        ..supportsInAppInstall = false
        ..abis = const <String>[]
        ..outcome = AppUpdateCheckOutcome(
          fakeRelease(desktop: true),
          AppUpdateSource.direct,
        );

      await pumpHome(tester);
      await tester.pump(AppUpdateAutoChecker.launchDelay);
      await tester.pumpAndSettle();
      expect(service.fetchCount, 1);
      expect(find.text('立即更新'), findsNothing);
      await tester.tap(find.text('前往下载'));
      await tester.pumpAndSettle();

      expect(launched, <String>[
        'https://github.com/CikeSeven/jotsy/releases/download/v0.6.1/'
            'jotsy-v0.6.1-linux-x64.tar.gz',
      ]);
      // 不进入更新页。
      expect(find.text('home'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
