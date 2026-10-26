import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/diary_drafts_harness.dart';

/// 编辑器设置分组：“新建时提示选择模板”开关只留在模板管理页，这里只保留
/// “日记模板”入口；“始终显示工具栏”开关默认关，切换后写入本机偏好。
void main() {
  testWidgets(
    'editor settings no longer shows the template suggestion switch but keeps the templates entry',
    (tester) async {
      final h = await DiaryDraftsHarness.create(tester);
      await h.pump(
        Scaffold(
          body: ListView(
            children: <Widget>[
              SettingsEditorSection(settingsAsync: AsyncData(h.settings)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(h.l10n.diaryTemplatesTitle), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(h.l10n.diaryTemplatesStripSwitch),
          matching: find.byType(SwitchListTile),
        ),
        findsNothing,
      );
      await h.unmount();
    },
  );

  testWidgets('the always-show toolbar switch is off by default and persists', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(
      Scaffold(
        body: ListView(
          children: <Widget>[
            SettingsEditorSection(settingsAsync: AsyncData(h.settings)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(
      SwitchListTile,
      h.l10n.settingsToolbarAlwaysVisible,
    );
    expect(tile, findsOneWidget);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(h.settings.isDiaryToolbarAlwaysVisible, isFalse);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    expect(h.settings.isDiaryToolbarAlwaysVisible, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('app.settings.diary_toolbar_always_visible'), isTrue);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(h.settings.isDiaryToolbarAlwaysVisible, isFalse);
    expect(prefs.getBool('app.settings.diary_toolbar_always_visible'), isFalse);
    await h.unmount();
  });

  testWidgets(
    'desktop hides the always-show toolbar switch because it is always on',
    (tester) async {
      final h = await DiaryDraftsHarness.create(tester);
      await h.pump(
        Scaffold(
          body: ListView(
            children: <Widget>[
              SettingsEditorSection(settingsAsync: AsyncData(h.settings)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(h.l10n.settingsToolbarAlwaysVisible), findsNothing);
      // Linux 不支持录音：工具栏预览里也没有它。
      expect(find.textContaining(h.l10n.diaryToolbarRecording), findsNothing);
      expect(find.text(h.l10n.diaryTemplatesTitle), findsOneWidget);
      await h.unmount();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('the toolbar preview keeps recording where it is supported', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(
      Scaffold(
        body: ListView(
          children: <Widget>[
            SettingsEditorSection(settingsAsync: AsyncData(h.settings)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(h.l10n.diaryToolbarRecording), findsOneWidget);
    await h.unmount();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
