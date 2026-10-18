import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';

import '../../../support/diary_drafts_harness.dart';

/// 编辑器设置分组：“新建时提示选择模板”开关只留在模板管理页，这里只保留
/// “日记模板”入口。
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
}
