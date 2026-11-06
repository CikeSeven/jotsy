import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/lan_sync/providers/lan_sync_providers.dart';
import 'package:node_diary/ui/notebooks/pages/notebooks_page.dart';
import 'package:node_diary/ui/settings/pages/app_features_page.dart';
import 'package:node_diary/ui/settings/pages/appearance_page.dart';
import 'package:node_diary/ui/settings/pages/data_management_page.dart';
import 'package:node_diary/ui/settings/pages/editor_settings_page.dart';
import 'package:node_diary/ui/settings/pages/mood_options_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/ui/settings/widgets/settings_card_group.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_lan_sync_controller.dart';

/// 设置首页（DESIGN.md §5.3）：通用、写日记、整理、数据与安全四组，末尾
/// AI 助手与关于；功能关闭时对应的行不出现；语言行显示并切换当前语言。
void main() {
  /// 存储的界面语言设为中文（与夹具里 MaterialApp 的语言一致），并用更高的
  /// 竖屏让整页分组不用滚动就都建出来（夹具默认 400 × 900，在 create 里设，
  /// 所以要在它之后改）。
  Future<DiaryDraftsHarness> pumpSettings(
    WidgetTester tester, {
    String? featuresRaw,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = const Size(400, 1600);
    await h.settings.setAppLocaleCode('zh');
    if (featuresRaw != null) {
      await h.settings.setAppFeaturesRaw(featuresRaw);
    }
    await h.pump(
      const Scaffold(body: SettingsPage()),
      overrides: [
        lanSyncControllerProvider.overrideWithValue(FakeLanSyncController()),
      ],
    );
    await tester.pumpAndSettle();
    return h;
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  /// 标题为 [title] 的分组里，相邻两行之间的分割线条数。
  int dividersIn(WidgetTester tester, String title) => tester
      .widgetList(
        find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(SettingsCardGroup),
          ),
          matching: find.byType(SettingsCardGroupDivider),
        ),
      )
      .length;

  testWidgets('groups and rows follow the settings home order', (tester) async {
    final h = await pumpSettings(tester, featuresRaw: '{"ai":true}');
    final l10n = h.l10n;

    final order = <String>[
      l10n.settingsGroupGeneral,
      l10n.settingsAppearance,
      l10n.settingsLanguage,
      l10n.settingsFeaturesTitle,
      l10n.settingsGroupWriting,
      l10n.settingsEditor,
      l10n.diaryTemplatesTitle,
      l10n.diaryDraftsTitle,
      l10n.settingsGroupOrganize,
      l10n.settingsTagManagement,
      l10n.settingsMoodOptionsTitle,
      l10n.notebookTitle,
      l10n.settingsRecycleBin,
      l10n.settingsGroupDataSecurity,
      l10n.settingsDataManagement,
      l10n.lanSyncTitle,
      l10n.settingsAppLockAndPasscode,
      l10n.aiSettingsTitle,
      l10n.settingsAbout,
    ];
    for (final text in order) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    for (var i = 1; i < order.length; i++) {
      expect(
        top(tester, order[i]),
        greaterThan(top(tester, order[i - 1])),
        reason: '${order[i - 1]} → ${order[i]}',
      );
    }
    // 只是进入列表的行不写副标题；外观、数据管理写内容概括。
    expect(find.text(l10n.settingsAppearanceSubtitle), findsOneWidget);
    expect(find.text(l10n.settingsDataManagementSubtitle), findsOneWidget);
    expect(dividersIn(tester, l10n.settingsGroupOrganize), 3);
    await h.unmount();
  });

  testWidgets('rows of turned-off features are left out without extra lines', (
    tester,
  ) async {
    final h = await pumpSettings(
      tester,
      featuresRaw: '{"notebooks":false,"templates":false,"ai":false}',
    );
    final l10n = h.l10n;

    expect(find.text(l10n.notebookTitle), findsNothing);
    expect(find.byIcon(FontAwesomeIcons.book.data), findsNothing);
    expect(find.text(l10n.diaryTemplatesTitle), findsNothing);
    expect(find.text(l10n.aiSettingsTitle), findsNothing);
    // 分组按项数插分割线：少了一行就少一条。
    expect(dividersIn(tester, l10n.settingsGroupOrganize), 2);
    expect(dividersIn(tester, l10n.settingsGroupWriting), 1);
    expect(find.text(l10n.settingsAbout), findsOneWidget);
    await h.unmount();
  });

  testWidgets('the language row shows the current language and switches it', (
    tester,
  ) async {
    final h = await pumpSettings(tester);
    expect(find.text('中文'), findsOneWidget);

    await tester.tap(find.text(h.l10n.settingsLanguage));
    await tester.pumpAndSettle();
    expect(find.text(h.l10n.languageDialogTitle), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(h.settings.appLocaleCode, 'en');
    expect(find.text('English'), findsOneWidget);
    expect(find.text('中文'), findsNothing);
    await h.unmount();
  });

  testWidgets('rows open their pages', (tester) async {
    final h = await pumpSettings(tester);
    final l10n = h.l10n;
    final targets = <String, Type>{
      l10n.settingsAppearance: AppearancePage,
      l10n.settingsFeaturesTitle: AppFeaturesPage,
      l10n.settingsEditor: EditorSettingsPage,
      l10n.settingsMoodOptionsTitle: MoodOptionsPage,
      l10n.notebookTitle: NotebooksPage,
      l10n.settingsDataManagement: DataManagementPage,
    };
    for (final MapEntry(key: title, value: page) in targets.entries) {
      await tester.tap(find.text(title));
      await h.settle();
      await tester.pumpAndSettle();
      expect(find.byType(page), findsOneWidget, reason: title);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await h.settle();
      await tester.pumpAndSettle();
      expect(find.byType(page), findsNothing, reason: title);
    }
    await h.unmount();
  });
}
