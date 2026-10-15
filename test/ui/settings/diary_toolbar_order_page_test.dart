import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
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

Finder get _overflowDivider => find.text('以下收进「更多」');

/// 360dp 宽手机：编辑器工具栏一排常驻默认顺序的前 6 个。
void _usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

double _labelY(WidgetTester tester, DiaryToolbarItem item) {
  final l10n = lookupAppLocalizations(const Locale('zh'));
  return tester.getCenter(find.text(item.label(l10n))).dy;
}

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

  testWidgets('a divider marks which tools stay on the editor toolbar', (
    tester,
  ) async {
    _usePhoneScreen(tester);
    await _pumpOrderPage(tester);

    expect(_overflowDivider, findsOneWidget);
    final dividerY = tester.getCenter(_overflowDivider).dy;
    expect(_labelY(tester, DiaryToolbarItem.underline), lessThan(dividerY));
    expect(_labelY(tester, DiaryToolbarItem.bulletList), greaterThan(dividerY));
  });

  testWidgets('dragging a tool across the divider moves it into More', (
    tester,
  ) async {
    _usePhoneScreen(tester);
    final settings = await _pumpOrderPage(tester);
    final handle = find.descendant(
      of: find.byKey(const ValueKey<String>('undo')),
      matching: find.byType(ReorderableDragStartListener),
    );
    final undoTile = tester.getRect(find.byKey(const ValueKey<String>('undo')));
    final divider = tester.getRect(
      find.byKey(const ValueKey<String>('toolbar-overflow-divider')),
    );

    // 把“撤销”拖到分界线正下方：拖动条目的底边对齐分界线的底边。
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    final distance = divider.bottom - undoTile.bottom;
    const steps = 20;
    for (var step = 0; step < steps; step++) {
      await gesture.moveBy(Offset(0, distance / steps));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // 它留在线下方，原先线下第一个工具补位上去。
    final dividerY = tester.getCenter(_overflowDivider).dy;
    expect(_labelY(tester, DiaryToolbarItem.undo), greaterThan(dividerY));
    expect(_labelY(tester, DiaryToolbarItem.bulletList), lessThan(dividerY));

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(
      decodeDiaryToolbarOrder(settings.diaryToolbarOrderRaw).take(7),
      <DiaryToolbarItem>[
        DiaryToolbarItem.redo,
        DiaryToolbarItem.recording,
        DiaryToolbarItem.bold,
        DiaryToolbarItem.italic,
        DiaryToolbarItem.underline,
        DiaryToolbarItem.bulletList,
        DiaryToolbarItem.undo,
      ],
    );
  });
}
