import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/notebooks/pages/notebooks_page.dart';
import 'package:node_diary/ui/settings/pages/app_features_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';

import '../../support/diary_drafts_harness.dart';

/// 设置首页的“日记本”入口：紧跟“标签管理”，点按进入日记本管理页；日记本
/// 功能关闭时隐藏。“功能管理”入口紧跟“编辑器设置”。
void main() {
  testWidgets('settings home links to the notebooks page', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const Scaffold(body: SettingsPage()));
    await tester.pumpAndSettle();

    final entry = find.text('日记本');
    expect(entry, findsOneWidget);
    expect(find.text('整理、排序、合并你的日记本'), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.book.data), findsOneWidget);
    // 位置在“标签管理”之后。
    expect(
      tester.getTopLeft(entry).dy,
      greaterThan(
        tester.getTopLeft(find.text(h.l10n.settingsTagManagement)).dy,
      ),
    );

    await tester.tap(entry);
    await h.settle();
    await tester.pumpAndSettle();
    expect(find.byType(NotebooksPage), findsOneWidget);
    await h.unmount();
  });

  testWidgets('notebooks entry is hidden when notebooks are turned off', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.settings.setAppFeaturesRaw('{"notebooks":false}');
    await h.pump(const Scaffold(body: SettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('整理、排序、合并你的日记本'), findsNothing);
    expect(find.byIcon(FontAwesomeIcons.book.data), findsNothing);
    // 隐藏时连同间距一起去掉：标签管理与数据与隐私之间仍是 12dp。
    Finder card(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(Card));
    final tagBottom = tester
        .getBottomLeft(card(h.l10n.settingsTagManagement))
        .dy;
    final privacyTop = tester.getTopLeft(card(h.l10n.settingsDataPrivacy)).dy;
    expect(privacyTop - tagBottom, 12);
    await h.unmount();
  });

  testWidgets('features entry follows the editor entry and opens its page', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const Scaffold(body: SettingsPage()));
    await tester.pumpAndSettle();

    final entry = find.text(h.l10n.settingsFeaturesTitle);
    expect(entry, findsOneWidget);
    expect(find.text(h.l10n.settingsFeaturesSubtitle), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.toggleOn.data), findsOneWidget);
    final entryTop = tester.getTopLeft(entry).dy;
    expect(
      entryTop,
      greaterThan(tester.getTopLeft(find.text(h.l10n.settingsEditorTitle)).dy),
    );
    expect(
      entryTop,
      lessThan(tester.getTopLeft(find.text(h.l10n.settingsTagManagement)).dy),
    );

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(AppFeaturesPage), findsOneWidget);
    await h.unmount();
  });
}
