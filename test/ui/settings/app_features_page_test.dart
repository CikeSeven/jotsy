import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:node_diary/ui/settings/pages/app_features_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:node_diary/core/services/settings_service.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/expressive_test_theme.dart';
import '../notebooks/notebook_test_support.dart';

/// 功能管理页：每个开关立即写入设置；纪念日随日历联动；关闭日记本时若有
/// 隐藏 / 上锁的本子先确认。
void main() {
  Finder switchTile(String title) => find.widgetWithText(SwitchListTile, title);

  SwitchListTile tile(WidgetTester tester, String title) =>
      tester.widget<SwitchListTile>(switchTile(title));

  AppFeatures stored(DiaryDraftsHarness h) =>
      AppFeatures.decode(h.settings.appFeaturesRaw);

  Future<void> toggle(WidgetTester tester, String title) async {
    await tester.ensureVisible(switchTile(title));
    await tester.tap(switchTile(title));
    await tester.pumpAndSettle();
  }

  testWidgets('each switch writes its feature immediately', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const AppFeaturesPage());
    final l10n = h.l10n;

    await toggle(tester, l10n.navCalendar);
    expect(stored(h).calendar, isFalse);
    await toggle(tester, l10n.navCalendar);
    expect(stored(h), AppFeatures.defaults);
    expect(h.settings.appFeaturesRaw, isNull);

    await toggle(tester, l10n.navExplore);
    expect(stored(h).explore, isFalse);
    await toggle(tester, l10n.settingsFeaturesAnniversaries);
    expect(stored(h).anniversaries, isFalse);
    await toggle(tester, l10n.settingsFeaturesTemplates);
    expect(stored(h).templates, isFalse);
    await toggle(tester, l10n.settingsFeaturesTimeCapsules);
    expect(stored(h).timeCapsules, isFalse);
    await toggle(tester, l10n.notebookTitle);
    await h.settle();
    expect(stored(h).notebooks, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tile(tester, l10n.notebookTitle).value, isFalse);

    // 打开日记本从不询问。
    await toggle(tester, l10n.notebookTitle);
    expect(find.byType(AlertDialog), findsNothing);
    expect(stored(h).notebooks, isTrue);
    await h.unmount();
  });

  testWidgets(
    'anniversaries follow the calendar and restore the stored value',
    (tester) async {
      final h = await DiaryDraftsHarness.create(tester);
      await h.pump(const AppFeaturesPage());
      final l10n = h.l10n;

      await toggle(tester, l10n.navCalendar);
      final linked = tile(tester, l10n.settingsFeaturesAnniversaries);
      expect(linked.value, isFalse);
      expect(linked.onChanged, isNull);
      expect(find.text(l10n.settingsFeaturesAnniversariesLinked), findsOne);
      // 联动关闭不改写用户自己的值。
      expect(stored(h).anniversaries, isTrue);

      await toggle(tester, l10n.navCalendar);
      expect(tile(tester, l10n.settingsFeaturesAnniversaries).value, isTrue);
      expect(find.text(l10n.settingsFeaturesAnniversariesSubtitle), findsOne);

      // 先单独关掉纪念日，再关开日历：回来时仍是关。
      await toggle(tester, l10n.settingsFeaturesAnniversaries);
      await toggle(tester, l10n.navCalendar);
      await toggle(tester, l10n.navCalendar);
      final restored = tile(tester, l10n.settingsFeaturesAnniversaries);
      expect(restored.value, isFalse);
      expect(restored.onChanged, isNotNull);
      await h.unmount();
    },
  );

  testWidgets('turning notebooks off with a private notebook asks first', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.notebook('日常');
    await h.notebook('秘密', visibility: NotebookVisibility.locked);
    await h.notebook('收起', visibility: NotebookVisibility.hidden);
    await h.pump(const AppFeaturesPage());
    final l10n = h.l10n;

    await toggle(tester, l10n.notebookTitle);
    await h.settle();
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsFeaturesNotebooksOffTitle), findsOne);
    expect(find.text(l10n.settingsFeaturesNotebooksOffMessage(2)), findsOne);

    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(stored(h).notebooks, isTrue);
    expect(tile(tester, l10n.notebookTitle).value, isTrue);

    await toggle(tester, l10n.notebookTitle);
    await h.settle();
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsFeaturesNotebooksOffConfirm));
    await tester.pumpAndSettle();
    await h.settle();
    expect(stored(h).notebooks, isFalse);
    expect(tile(tester, l10n.notebookTitle).value, isFalse);
    await h.unmount();
  });

  testWidgets('only normal notebooks turn off without asking', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.notebook('日常');
    await h.pump(const AppFeaturesPage());

    await toggle(tester, h.l10n.notebookTitle);
    await h.settle();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(stored(h).notebooks, isFalse);
    await h.unmount();
  });

  for (final locale in const <Locale>[Locale('zh'), Locale('en')]) {
    testWidgets('renders without overflow at 320dp in ${locale.languageCode}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{
        // 日历关闭，让最长的联动说明也参与布局。
        'app.settings.app_features': '{"calendar":false}',
      });
      final settings = await SettingsService.create();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWith((ref) async => settings),
            notebooksProvider.overrideWith(
              (ref) => Stream.value(const <NotebookView>[]),
            ),
          ],
          child: MaterialApp(
            theme: expressiveTestTheme(Brightness.light),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppFeaturesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SwitchListTile), findsNWidgets(6));
    });
  }
}
