import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/diary_toolbar_order_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

Future<SettingsService> _pumpOrderPage(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = await SettingsService.create();
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Text('settings home')),
    ),
  );
  navigatorKey.currentState!.push(
    MaterialPageRoute<bool>(
      builder: (_) => DiaryToolbarOrderPage(settingsService: settings),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

Finder get _backButton => find.byTooltip('返回');

void main() {
  testWidgets('back without changes leaves immediately', (tester) async {
    await _pumpOrderPage(tester);
    await tester.tap(_backButton);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('settings home'), findsOneWidget);
  });

  testWidgets('back with unsaved changes asks before discarding', (
    tester,
  ) async {
    final settings = await _pumpOrderPage(tester);
    final hiddenBefore = settings.diaryToolbarHiddenItemsRaw;
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    await tester.tap(_backButton);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // 取消：留在排序页，修改仍在。
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryToolbarOrderPage), findsOneWidget);

    // 放弃：离开且不写入设置。
    await tester.tap(_backButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '退出'));
    await tester.pumpAndSettle();
    expect(find.text('settings home'), findsOneWidget);
    expect(settings.diaryToolbarHiddenItemsRaw, hiddenBefore);
  });

  testWidgets('save and exit persists the pending changes', (tester) async {
    final settings = await _pumpOrderPage(tester);
    final hiddenBefore = settings.diaryToolbarHiddenItemsRaw;
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    await tester.tap(_backButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '保存并退出'));
    await tester.pumpAndSettle();

    expect(find.text('settings home'), findsOneWidget);
    expect(settings.diaryToolbarHiddenItemsRaw, isNot(hiddenBefore));
  });
}
