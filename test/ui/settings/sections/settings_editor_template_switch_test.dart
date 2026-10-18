import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_prefs.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_templates_page.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';

import '../../../support/diary_drafts_harness.dart';

/// 编辑器设置里的“新建时提示选择模板”开关：与模板管理页共用同一份偏好。
void main() {
  DiaryTemplatePrefs prefs(DiaryDraftsHarness h) =>
      DiaryTemplatePrefs.decode(h.settings.diaryTemplatePrefsRaw);

  Finder switchOf(DiaryDraftsHarness h) => find.ancestor(
    of: find.text(h.l10n.diaryTemplatesStripSwitch),
    matching: find.byType(SwitchListTile),
  );

  bool valueOf(WidgetTester tester, Finder f) =>
      tester.widget<SwitchListTile>(f).value;

  Future<DiaryDraftsHarness> open(WidgetTester tester, String raw) async {
    final h = await DiaryDraftsHarness.create(tester);
    await tester.runAsync(() => h.settings.setDiaryTemplatePrefsRaw(raw));
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
    return h;
  }

  Future<void> toggle(DiaryDraftsHarness h) async {
    await h.tester.tap(switchOf(h));
    await h.tester.pumpAndSettle();
    await h.settle();
    await h.tester.pumpAndSettle();
  }

  testWidgets(
    'turning off the editor settings switch keeps other prefs and syncs the template page',
    (tester) async {
      final h = await open(
        tester,
        '{"v":1,"hidden":["builtin.dream"],"recent":["builtin.daily"]}',
      );
      expect(valueOf(tester, switchOf(h)), isTrue);

      await toggle(h);
      expect(prefs(h).showStrip, isFalse);
      expect(prefs(h).hiddenBuiltIns, {'builtin.dream'});
      expect(prefs(h).recent, ['builtin.daily']);
      expect(valueOf(tester, switchOf(h)), isFalse);

      await tester.tap(find.text(h.l10n.diaryTemplatesTitle));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryTemplatesPage), findsOneWidget);
      expect(valueOf(tester, switchOf(h).last), isFalse);
      await h.unmount();
    },
  );

  testWidgets('turning the editor settings switch back on restores showStrip', (
    tester,
  ) async {
    final h = await open(
      tester,
      '{"v":1,"strip":false,"recent":["builtin.daily"]}',
    );
    expect(valueOf(tester, switchOf(h)), isFalse);

    await toggle(h);
    expect(prefs(h).showStrip, isTrue);
    expect(prefs(h).recent, ['builtin.daily']);
    expect(valueOf(tester, switchOf(h)), isTrue);
    await h.unmount();
  });
}
