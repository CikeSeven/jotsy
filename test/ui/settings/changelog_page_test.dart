import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/about_page.dart';
import 'package:node_diary/ui/settings/pages/changelog_page.dart';
import 'package:node_diary/ui/settings/providers/changelog_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_app_update_service.dart';
import '../../support/fake_release_notes_bundle.dart';

void main() {
  // 假服务里本机装的是 0.6.0+17。
  FakeReleaseNotesBundle bundleWithThreeVersions() =>
      FakeReleaseNotesBundle(<String, String>{
        'docs/releases/v0.6.1.md': releaseNotesMarkdown(
          'v0.6.1',
          highlights: <String>['应用内更新全面重做'],
          rest: '## 修复\n- 修复新版本里的问题',
        ),
        'docs/releases/v0.6.1.en.md': releaseNotesMarkdown(
          'v0.6.1',
          english: true,
          highlights: <String>['In-app updates, rebuilt'],
          rest: '## Fixes\n- Fixed a newer issue',
        ),
        'docs/releases/v0.6.0.md': releaseNotesMarkdown(
          'v0.6.0',
          highlights: <String>['网盘备份'],
          rest: '## 新增\n- 从 18 款应用导入',
        ),
        'docs/releases/v0.6.0.en.md': releaseNotesMarkdown(
          'v0.6.0',
          english: true,
          highlights: <String>['Cloud backup'],
          rest: '## New\n- Import from 18 apps',
        ),
        'docs/releases/v0.5.1.md':
            '# Release v0.5.1\n\n[English](./v0.5.1.en.md) | 简体中文\n\n'
            '- 新增日记录音与播放\n',
      });

  Future<void> pumpApp(
    WidgetTester tester, {
    required Widget home,
    AssetBundle? bundle,
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('zh'),
    Size size = const Size(400, 860),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = (await tester.runAsync(SettingsService.create))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
          appUpdateServiceProvider.overrideWithValue(FakeAppUpdateService()),
          releaseNotesBundleProvider.overrideWithValue(
            bundle ?? bundleWithThreeVersions(),
          ),
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
          home: home,
        ),
      ),
    );
    // 资源包在真实异步里读取（假资源包同样走 Future）。
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('lists versions newest first and marks the installed one '
        '(${brightness.name})', (tester) async {
      await pumpApp(
        tester,
        home: const ChangelogPage(),
        brightness: brightness,
        size: const Size(320, 640),
        textScale: 1.3,
      );

      expect(find.text('更新日志'), findsOneWidget);
      final newest = tester.getTopLeft(find.text('v0.6.1'));
      final installed = tester.getTopLeft(find.text('v0.6.0'));
      expect(newest.dy, lessThan(installed.dy));
      expect(find.text('应用内更新全面重做'), findsOneWidget);
      expect(find.text('网盘备份'), findsOneWidget);
      // 只有本机安装的版本带“当前版本”，而且就在它那一行。
      expect(find.text('当前版本'), findsOneWidget);
      expect(
        tester.getCenter(find.text('当前版本')).dy,
        moreOrLessEquals(tester.getCenter(find.text('v0.6.0')).dy, epsilon: 4),
      );
      // 页面标题与“版本要点”标题不重复出现在卡片里。
      expect(find.text('版本要点'), findsNothing);

      await tester.scrollUntilVisible(find.text('新增日记录音与播放'), 200);
      expect(find.text('v0.5.1'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('在 GitHub 查看全部版本'), 200);
    });
  }

  testWidgets('expands the rest of a version and collapses it again', (
    tester,
  ) async {
    await pumpApp(tester, home: const ChangelogPage());

    // v0.5.1 没有其余章节，不显示“展开全部”。
    expect(find.text('展开全部'), findsNWidgets(2));
    expect(find.text('修复新版本里的问题'), findsNothing);

    await tester.tap(find.text('展开全部').first);
    await tester.pumpAndSettle();
    expect(find.text('修复'), findsOneWidget);
    expect(find.text('修复新版本里的问题'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);
    // 只展开点按的那一版。
    expect(find.text('从 18 款应用导入'), findsNothing);

    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(find.text('修复新版本里的问题'), findsNothing);
    expect(find.text('展开全部'), findsNWidgets(2));
  });

  testWidgets('shows English notes in an English interface', (tester) async {
    await pumpApp(
      tester,
      home: const ChangelogPage(),
      locale: const Locale('en'),
    );

    expect(find.text('Changelog'), findsOneWidget);
    expect(find.text('In-app updates, rebuilt'), findsOneWidget);
    expect(find.text('Cloud backup'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Show all'), findsNWidgets(2));
    // v0.5.1 只有中文说明，英文界面回落到中文。
    await tester.scrollUntilVisible(find.text('新增日记录音与播放'), 200);
  });

  testWidgets('shows the empty state when the notes cannot be read', (
    tester,
  ) async {
    await pumpApp(
      tester,
      home: const ChangelogPage(),
      bundle: FakeReleaseNotesBundle(
        const <String, String>{},
        manifestFails: true,
      ),
    );

    expect(find.text('暂时没有可显示的更新日志。'), findsOneWidget);
    expect(find.text('展开全部'), findsNothing);
  });

  testWidgets('opens the changelog from the About page', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Jotsy',
      packageName: 'com.jotsy.diary',
      version: '0.6.0',
      buildNumber: '17',
      buildSignature: '',
    );
    await pumpApp(tester, home: const AboutPage());

    await tester.tap(find.text('更新日志'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogPage), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
  });
}
