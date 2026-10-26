import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/app_update_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/app_update_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_app_update_service.dart';

void main() {
  late FakeAppUpdateService service;
  late SettingsService settings;

  setUp(() {
    service = FakeAppUpdateService()
      ..outcome = AppUpdateCheckOutcome(fakeRelease(), AppUpdateSource.direct);
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('zh'),
    Size size = const Size(400, 860),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = (await tester.runAsync(SettingsService.create))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
          appUpdateServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(brightness),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const AppUpdatePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('shows the new version and notes without overflow at 320dp '
        '(${brightness.name})', (tester) async {
      await pumpPage(
        tester,
        brightness: brightness,
        size: const Size(320, 640),
        textScale: 1.3,
      );

      expect(find.text('发现新版本 v0.6.1'), findsOneWidget);
      expect(find.text('当前版本 0.6.0 (17)'), findsOneWidget);
      expect(find.text('新增'), findsOneWidget);
      expect(find.text('下载并安装（49 MB）'), findsOneWidget);
      expect(find.text('跳过此版本'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('下载线路'), 200);
      expect(find.text('自动选择'), findsOneWidget);
    });
  }

  testWidgets('shows progress, cancels and offers to resume', (tester) async {
    service.downloadCompleter = Completer<File>();
    await pumpPage(tester);

    await tester.tap(find.text('下载并安装（49 MB）'));
    await tester.pump();
    service.onProgress!(
      const AppUpdateDownloadProgress(
        received: 20 << 20,
        total: 40 << 20,
        bytesPerSecond: 1048576,
        source: AppUpdateSource('ghfast', 'https://ghfast.top/'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20 MB / 40 MB'), findsOneWidget);
    expect(find.text('1 MB/s'), findsOneWidget);
    expect(find.text('经 ghfast.top'), findsOneWidget);

    await tester.tap(find.text('取消下载'));
    await tester.pumpAndSettle();
    expect(find.text('继续下载（已完成 50%）'), findsOneWidget);
  });

  testWidgets('asks for the install permission and installs on return', (
    tester,
  ) async {
    service.canInstall = false;
    await pumpPage(tester);

    await tester.tap(find.text('下载并安装（49 MB）'));
    await tester.pumpAndSettle();
    expect(find.text('需要允许安装应用'), findsOneWidget);
    expect(service.installCount, 0);

    await tester.tap(find.text('去设置'));
    await tester.pump();
    expect(service.openSettingsCount, 1);

    service.canInstall = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(service.installCount, 1);
    expect(find.text('安装'), findsOneWidget);
  });

  testWidgets('validates and saves a custom mirror', (tester) async {
    await pumpPage(tester, size: const Size(400, 1400));
    await tester.tap(find.text('下载线路'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('自定义镜像'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'mirror.example');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入以 https:// 开头的地址'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'https://mirror.example');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final stored = AppUpdatePreferences.decode(
      settings.appUpdatePreferencesRaw,
    );
    expect(stored.sourceId, AppUpdateSource.customId);
    expect(stored.customMirror, 'https://mirror.example/');
    expect(find.text('自定义镜像 · mirror.example'), findsOneWidget);
  });

  testWidgets('says up to date in English with the current notes', (
    tester,
  ) async {
    service.outcome = AppUpdateCheckOutcome(
      fakeRelease(version: '0.6.0+17'),
      AppUpdateSource.direct,
    );
    await pumpPage(tester, locale: const Locale('en'));

    expect(find.text("You're up to date"), findsOneWidget);
    expect(find.text('In this version'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
  });

  group('desktop', () {
    /// 拦截 url_launcher 的方法通道，记下在浏览器里打开的地址。
    List<String> captureLaunches() {
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
      return launched;
    }

    testWidgets('offers a browser download instead of the install flow', (
      tester,
    ) async {
      service
        ..supportsInAppInstall = false
        ..abis = const <String>[]
        ..outcome = AppUpdateCheckOutcome(
          fakeRelease(desktop: true),
          AppUpdateSource.builtInSources.first,
        );
      final launched = captureLaunches();
      await pumpPage(tester, size: const Size(320, 640), textScale: 1.3);

      final linux = debugDefaultTargetPlatformOverride == TargetPlatform.linux;
      expect(find.text('发现新版本 v0.6.1'), findsOneWidget);
      expect(find.text('前往下载'), findsOneWidget);
      expect(find.text('在 GitHub 查看'), findsOneWidget);
      expect(find.text('跳过此版本'), findsOneWidget);
      expect(find.textContaining('下载并安装'), findsNothing);
      expect(find.textContaining('arm64-v8a'), findsNothing);
      expect(
        find.textContaining(linux ? 'install.sh' : '运行它即可覆盖安装'),
        findsOneWidget,
      );

      await tester.tap(find.text('前往下载'));
      await tester.pumpAndSettle();
      final name = linux
          ? 'jotsy-v0.6.1-linux-x64.tar.gz'
          : 'jotsy-v0.6.1-windows-x64-setup.exe';
      expect(launched, <String>[
        '${AppUpdateSource.builtInSources.first.prefix}'
            'https://github.com/CikeSeven/jotsy/releases/download/v0.6.1/$name',
      ]);
      expect(service.installCount, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Windows opens the installer from the update page', (
      tester,
    ) async {
      service
        ..supportsInAppInstall = false
        ..abis = const <String>[]
        ..outcome = AppUpdateCheckOutcome(
          fakeRelease(desktop: true),
          AppUpdateSource.direct,
        );
      final launched = captureLaunches();
      await pumpPage(tester, locale: const Locale('en'));

      expect(find.text('Download'), findsOneWidget);
      expect(find.textContaining('Download and install'), findsNothing);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(launched.single, endsWith('jotsy-v0.6.1-windows-x64-setup.exe'));
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('an APK-only release sends desktop users to the release page', (
      tester,
    ) async {
      service
        ..supportsInAppInstall = false
        ..abis = const <String>[]
        ..outcome = AppUpdateCheckOutcome(
          fakeRelease(),
          AppUpdateSource.direct,
        );
      final launched = captureLaunches();
      await pumpPage(tester);

      expect(find.text('前往下载'), findsNothing);
      expect(find.text('这个版本没有适合本机系统的安装包，请前往下载页面查看。'), findsOneWidget);
      await tester.tap(find.text('前往下载页面'));
      await tester.pumpAndSettle();
      expect(launched, <String>[fakeRelease().pageUrl.toString()]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  testWidgets('explains a failed check and retries', (tester) async {
    service.outcome = null;
    await pumpPage(tester);
    expect(find.text('检查更新失败'), findsOneWidget);

    service.outcome = AppUpdateCheckOutcome(
      fakeRelease(),
      AppUpdateSource.direct,
    );
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 v0.6.1'), findsOneWidget);
  });
}
