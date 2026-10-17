import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_update_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/widgets/app_update_available_sheet.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_app_update_service.dart';

void main() {
  /// 放一个按钮打开提示面板，所选操作写入 [onResult]。
  Future<void> pumpLauncher(
    WidgetTester tester, {
    required ValueChanged<AppUpdatePromptAction> onResult,
    Brightness brightness = Brightness.light,
  }) async {
    final release = fakeRelease();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(
                await showAppUpdateAvailableSheet(
                  context,
                  release: release,
                  installed: const AppVersion(0, 6, 0, build: 17),
                  asset: release.assets.first,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'lists the version, notes and actions at 320dp (${brightness.name})',
      (tester) async {
        await pumpLauncher(tester, brightness: brightness, onResult: (_) {});
        await open(tester);

        expect(find.text('发现新版本 v0.6.1'), findsOneWidget);
        expect(find.textContaining('当前版本 0.6.0 (17)'), findsOneWidget);
        expect(find.textContaining('49 MB'), findsOneWidget);
        expect(find.text('应用内更新与下载线路'), findsOneWidget);
        expect(find.text('立即更新'), findsOneWidget);
        expect(find.text('跳过此版本'), findsOneWidget);
        expect(find.text('以后再说'), findsOneWidget);
      },
    );
  }

  testWidgets('returns the chosen action and treats dismissal as later', (
    tester,
  ) async {
    AppUpdatePromptAction? chosen;
    await pumpLauncher(tester, onResult: (action) => chosen = action);

    await open(tester);
    await tester.tap(find.text('跳过此版本'));
    await tester.pumpAndSettle();
    expect(chosen, AppUpdatePromptAction.skip);

    await open(tester);
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();
    expect(chosen, AppUpdatePromptAction.update);

    await open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(chosen, AppUpdatePromptAction.later);
  });
}
