import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/backup_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_behavior.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/diary_drafts_harness.dart';

/// 编辑器设置分组：“新建时提示选择模板”开关只留在模板管理页，这里只保留
/// “日记模板”入口；“始终显示工具栏”开关默认关，切换后写入本机偏好；
/// “打开日记时直接编辑”默认关，写进预览页的阅读行为；“工具栏大小”默认
/// 标准，点选即写入本机偏好，不进备份。
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

  testWidgets('the toolbar size defaults to standard and persists locally', (
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

    expect(find.text(h.l10n.diaryToolbarSizeTitle), findsOneWidget);
    bool selected(String label) =>
        tester
            .widget<Semantics>(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is Semantics &&
                          widget.properties.inMutuallyExclusiveGroup == true,
                    ),
                  )
                  .first,
            )
            .properties
            .selected ??
        false;
    expect(selected(h.l10n.diaryToolbarSizeStandard), isTrue);
    expect(h.settings.diaryToolbarSizeRaw, isNull);

    await tester.tap(find.text(h.l10n.diaryToolbarSizeExtraLarge));
    await tester.pumpAndSettle();
    expect(selected(h.l10n.diaryToolbarSizeExtraLarge), isTrue);
    expect(selected(h.l10n.diaryToolbarSizeStandard), isFalse);
    expect(h.settings.diaryToolbarSizeRaw, 'extra_large');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app.settings.diary_toolbar_size'), 'extra_large');
    // 本机偏好：不随备份导出。
    expect(
      BackupSettings.capture(h.settings).values,
      isNot(contains('extra_large')),
    );
    await h.unmount();
  });

  testWidgets(
    'the open-in-editor switch is off by default and saves the preview behavior',
    (tester) async {
      final h = await DiaryDraftsHarness.create(tester);
      // 预览页样式页里已有别的阅读行为：开关只改这一项。
      await h.settings.setDiaryPreviewStyleRaw(
        const DiaryPreviewSettings(
          behavior: DiaryPreviewBehavior(todoToggle: false),
        ).encode(),
      );
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
        h.l10n.settingsOpenDiaryInEditor,
      );
      expect(tile, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      DiaryPreviewBehavior stored() => DiaryPreviewSettings.decode(
        h.settings.diaryPreviewStyleRawNotifier.value,
      ).behavior;

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      expect(stored().openInEditor, isTrue);
      expect(stored().todoToggle, isFalse);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect(stored(), const DiaryPreviewBehavior(todoToggle: false));
      await h.unmount();
    },
  );

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
