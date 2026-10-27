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
import 'package:node_diary/ui/settings/widgets/settings_option_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:node_diary/core/services/settings_service.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/expressive_test_theme.dart';
import '../notebooks/notebook_test_support.dart';

/// 功能管理页：每个开关立即写入设置；纪念日在日历下方、随日历显隐；关闭日记本时若有
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
    // 拨回默认也整份写入：有这个键就说明用户保存过，升级迁移不再改动。
    expect(h.settings.appFeaturesRaw, AppFeatures.defaults.encode());

    await toggle(tester, l10n.navExplore);
    expect(stored(h).explore, isFalse);
    // 纪念日默认关闭，拨一下是打开。
    await toggle(tester, l10n.settingsFeaturesAnniversaries);
    expect(stored(h).anniversaries, isTrue);
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

  testWidgets('anniversaries sit right below the calendar and write their '
      'own value', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const AppFeaturesPage());
    final l10n = h.l10n;

    // 「页面」组顺序：日历、纪念日、探索；「功能」组在其后。
    final calendarY = tester.getTopLeft(switchTile(l10n.navCalendar)).dy;
    final anniversaryY = tester
        .getTopLeft(switchTile(l10n.settingsFeaturesAnniversaries))
        .dy;
    final exploreY = tester.getTopLeft(switchTile(l10n.navExplore)).dy;
    final notebooksY = tester.getTopLeft(switchTile(l10n.notebookTitle)).dy;
    expect(calendarY, lessThan(anniversaryY));
    expect(anniversaryY, lessThan(exploreY));
    expect(exploreY, lessThan(notebooksY));

    // 视觉上从属于日历：标题比日历、探索都缩进一级。
    final calendarTitleX = tester.getTopLeft(find.text(l10n.navCalendar)).dx;
    final anniversaryTitleX = tester
        .getTopLeft(find.text(l10n.settingsFeaturesAnniversaries))
        .dx;
    expect(tester.getTopLeft(find.text(l10n.navExplore)).dx, calendarTitleX);
    expect(
      anniversaryTitleX - calendarTitleX,
      SettingsSwitchTile.nestedIndent - 16,
    );

    // 纪念日默认关闭，但日历开着时照样可以拨动。
    final anniversaries = tile(tester, l10n.settingsFeaturesAnniversaries);
    expect(anniversaries.value, isFalse);
    expect(anniversaries.onChanged, isNotNull);
    expect(find.text(l10n.settingsFeaturesAnniversariesSubtitle), findsOne);

    await toggle(tester, l10n.settingsFeaturesAnniversaries);
    expect(stored(h).anniversaries, isTrue);
    expect(stored(h).calendar, isTrue);
    await h.unmount();
  });

  testWidgets('anniversaries hide with the calendar and come back with the '
      'stored value', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const AppFeaturesPage());
    final l10n = h.l10n;
    // 纪念日默认关闭，先打开它。
    await toggle(tester, l10n.settingsFeaturesAnniversaries);

    await toggle(tester, l10n.navCalendar);
    expect(switchTile(l10n.settingsFeaturesAnniversaries), findsNothing);
    expect(find.text(l10n.settingsFeaturesAnniversariesSubtitle), findsNothing);
    // 日历关闭不改写用户自己的值。
    expect(stored(h).anniversaries, isTrue);

    await toggle(tester, l10n.navCalendar);
    expect(tile(tester, l10n.settingsFeaturesAnniversaries).value, isTrue);

    // 先单独关掉纪念日，再关开日历：回来时仍是关，且可以拨动。
    await toggle(tester, l10n.settingsFeaturesAnniversaries);
    await toggle(tester, l10n.navCalendar);
    expect(switchTile(l10n.settingsFeaturesAnniversaries), findsNothing);
    await toggle(tester, l10n.navCalendar);
    final restored = tile(tester, l10n.settingsFeaturesAnniversaries);
    expect(restored.value, isFalse);
    expect(restored.onChanged, isNotNull);
    expect(stored(h).anniversaries, isFalse);
    await h.unmount();
  });

  testWidgets('anniversaries slide in and out with the calendar without '
      'taking over the explore row', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const AppFeaturesPage());
    final l10n = h.l10n;
    Finder rowClip() => find.ancestor(
      of: switchTile(l10n.settingsFeaturesAnniversaries),
      matching: find.byType(SizeTransition),
    );

    // 探索关着时打开日历：纪念日一行若按位置接手探索那一行，开关会从“关”
    // 播一遍拨动动画；探索那一行必须还是原来的 element。纪念日默认关闭，
    // 先打开它，两行的开关值才不同。
    await toggle(tester, l10n.settingsFeaturesAnniversaries);
    await toggle(tester, l10n.navExplore);
    await toggle(tester, l10n.navCalendar);
    final exploreElement = tester.element(switchTile(l10n.navExplore));
    final exploreSwitch = tester.state(
      find
          .descendant(
            of: switchTile(l10n.navExplore),
            matching: find.byWidgetPredicate((w) => w is StatefulWidget),
          )
          .first,
    );

    await tester.tap(switchTile(l10n.navCalendar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 展开途中：已在树上、高度还没到整行。
    final fullHeight = tester
        .getSize(switchTile(l10n.settingsFeaturesAnniversaries))
        .height;
    expect(tester.getSize(rowClip()).height, lessThan(fullHeight));
    await tester.pumpAndSettle();
    expect(tester.getSize(rowClip()).height, greaterThanOrEqualTo(fullHeight));
    expect(tile(tester, l10n.settingsFeaturesAnniversaries).value, isTrue);
    expect(tester.element(switchTile(l10n.navExplore)), same(exploreElement));
    expect(
      tester.state(
        find
            .descendant(
              of: switchTile(l10n.navExplore),
              matching: find.byWidgetPredicate((w) => w is StatefulWidget),
            )
            .first,
      ),
      same(exploreSwitch),
    );

    // 收起途中仍在原处淡出，结束后移除。
    await tester.tap(switchTile(l10n.navCalendar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(switchTile(l10n.settingsFeaturesAnniversaries), findsOne);
    await tester.pumpAndSettle();
    expect(switchTile(l10n.settingsFeaturesAnniversaries), findsNothing);
    await h.unmount();
  });

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
      SharedPreferences.setMockInitialValues(<String, Object>{});
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
