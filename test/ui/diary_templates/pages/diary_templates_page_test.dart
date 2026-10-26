import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_auto_rule.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_code.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_json.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_prefs.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_auto_apply_page.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_editor_page.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_templates_page.dart';
import 'package:node_diary/ui/diary_templates/sections/diary_templates_settings_group.dart';

import '../../../support/diary_drafts_harness.dart';

/// 模板管理页：内置模板与我的模板、编辑与恢复默认、复制、删除的撤销与
/// 恢复、偏好、模板码。
void main() {
  Future<DiaryDraftsHarness> openPage(
    WidgetTester tester, {
    List<DiaryTemplate> seed = const <DiaryTemplate>[],
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    for (final template in seed) {
      await tester.runAsync(
        () => h.database.saveDiaryTemplate(
          templateId: template.id,
          name: template.name,
          payload: DiaryTemplateJson.toPayload(template),
        ),
      );
    }
    await h.pump(const DiaryTemplatesPage());
    await tester.pumpAndSettle();
    return h;
  }

  DiaryTemplatePrefs prefs(DiaryDraftsHarness h) =>
      DiaryTemplatePrefs.decode(h.settings.diaryTemplatePrefsRaw);

  // 列表很长：查找时不跳过滚出视野的行，点按前再滚进来。
  Finder builtIn(String key) => find.byKey(
    ValueKey<String>('template_builtin_builtin.$key'),
    skipOffstage: false,
  );
  Finder mine(String id) =>
      find.byKey(ValueKey<String>('template_mine_$id'), skipOffstage: false);

  /// 打开某一行的“更多操作”菜单。
  Future<void> openMenu(DiaryDraftsHarness h, Finder row) async {
    // 列表是懒构建的：先滚到这一行被构建出来，再把它的按钮滚进视野。
    await h.tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final button = find.descendant(
      of: row,
      matching: find.byTooltip(
        h.l10n.diaryTemplatesMoreActions,
        skipOffstage: false,
      ),
      skipOffstage: false,
    );
    await h.tester.ensureVisible(button);
    await h.tester.pumpAndSettle();
    await h.tester.tap(button);
    await h.tester.pumpAndSettle();
  }

  /// 打开某一行的“更多操作”菜单并点其中一项。
  Future<void> menu(DiaryDraftsHarness h, Finder row, String action) async {
    await openMenu(h, row);
    await h.tester.tap(find.text(action).last);
    await h.tester.pumpAndSettle();
    await h.settle();
    await h.tester.pumpAndSettle();
  }

  testWidgets('lists the built-ins and an empty hint for mine', (tester) async {
    final h = await openPage(tester);
    expect(find.text(h.l10n.diaryTemplatesMineEmpty), findsOneWidget);
    expect(builtIn('daily'), findsOneWidget);
    await h.unmount();
  });

  Future<void> settle(DiaryDraftsHarness h) async {
    await h.tester.pumpAndSettle();
    await h.settle();
    await h.tester.pumpAndSettle();
  }

  /// 把 [row] 滚进视野后点按。
  Future<void> tapRow(DiaryDraftsHarness h, Finder row) async {
    await h.tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await h.tester.pumpAndSettle();
    await h.tester.tap(row);
    await settle(h);
  }

  testWidgets('tapping a built-in edits it in place and marks it edited', (
    tester,
  ) async {
    final h = await openPage(tester);
    await tapRow(h, builtIn('daily'));
    expect(find.byType(DiaryTemplateEditorPage), findsOneWidget);
    expect(find.text(h.l10n.diaryTemplateEditorEditTitle), findsOneWidget);

    await tester.tap(find.text(h.l10n.diaryTemplateEditorTabSettings));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '我的每日');
    await tester.tap(find.text(h.l10n.commonSave));
    await settle(h);

    expect(find.byType(DiaryTemplateEditorPage), findsNothing);
    final rows = (await tester.runAsync(h.database.getDiaryTemplates))!;
    expect(rows.map((row) => (row.templateId, row.name)), [
      ('builtin.daily', '我的每日'),
    ]);
    // 仍在内置模板原来的位置，不算我的模板。
    expect(find.text(h.l10n.diaryTemplatesMineEmpty), findsOneWidget);
    expect(
      find.descendant(of: builtIn('daily'), matching: find.text('我的每日')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: builtIn('daily'),
        matching: find.text(h.l10n.diaryTemplateEditedBadge),
      ),
      findsOneWidget,
    );
    await h.unmount();
  });

  testWidgets('an edited built-in can be restored to the original, with '
      'undo', (tester) async {
    final h = await openPage(
      tester,
      seed: const [DiaryTemplate(id: 'builtin.morning', name: '早起')],
    );
    expect(
      find.descendant(of: builtIn('morning'), matching: find.text('早起')),
      findsOneWidget,
    );

    await menu(h, builtIn('morning'), h.l10n.diaryTemplatesResetBuiltIn);
    expect(find.text('已恢复「早起」的默认内容'), findsOneWidget);
    expect(
      find.descendant(of: builtIn('morning'), matching: find.text('晨间日记')),
      findsOneWidget,
    );
    expect((await tester.runAsync(h.database.getDiaryTemplates))!, isEmpty);

    await tester.tap(find.text(h.l10n.commonUndo));
    await settle(h);
    expect(
      find.descendant(of: builtIn('morning'), matching: find.text('早起')),
      findsOneWidget,
    );
    await h.unmount();
  });

  testWidgets('a built-in that was never edited has no restore-original '
      'action', (tester) async {
    final h = await openPage(tester);
    await openMenu(h, builtIn('weekly'));
    expect(find.text(h.l10n.commonEdit), findsOneWidget);
    expect(find.text(h.l10n.diaryTemplatesResetBuiltIn), findsNothing);
    expect(find.text(h.l10n.commonDelete), findsOneWidget);
    await h.unmount();
  });

  testWidgets('deleting my template can be undone', (tester) async {
    final h = await openPage(
      tester,
      seed: const [DiaryTemplate(id: 'mine-1', name: '我的模板甲')],
    );
    expect(mine('mine-1'), findsOneWidget);

    await menu(h, mine('mine-1'), h.l10n.commonDelete);
    expect(mine('mine-1'), findsNothing);
    expect(find.text('已删除「我的模板甲」'), findsOneWidget);

    await tester.tap(find.text(h.l10n.commonUndo));
    await tester.pumpAndSettle();
    await h.settle();
    await tester.pumpAndSettle();
    expect(mine('mine-1'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('deleting a built-in takes it off the list, and undo puts '
      'it back', (tester) async {
    final h = await openPage(tester);
    await menu(h, builtIn('gratitude'), h.l10n.commonDelete);
    expect(prefs(h).hiddenBuiltIns, {'builtin.gratitude'});
    expect(builtIn('gratitude'), findsNothing);
    expect(find.text('已删除「感恩日记」'), findsOneWidget);

    await tester.tap(find.text(h.l10n.commonUndo));
    await settle(h);
    expect(prefs(h).hiddenBuiltIns, isEmpty);
    expect(builtIn('gratitude'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('deleted built-ins come back from the restore sheet', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.settings.setDiaryTemplatePrefsRaw(
      DiaryTemplatePrefs.defaults
          .withHidden('builtin.gratitude', true)
          .withHidden('builtin.reading', true)
          .encode(),
    );
    await h.pump(const DiaryTemplatesPage());
    await tester.pumpAndSettle();
    expect(builtIn('gratitude'), findsNothing);
    expect(builtIn('reading'), findsNothing);

    final restoreRow = find.byKey(
      const ValueKey<String>('template_restore_row'),
      skipOffstage: false,
    );
    await tapRow(h, restoreRow);
    expect(find.text(h.l10n.diaryTemplatesRestoreSheetTitle), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('template_restore_builtin.reading'),
        ),
        matching: find.text(h.l10n.diaryTemplatesRestore),
      ),
    );
    await settle(h);
    expect(prefs(h).hiddenBuiltIns, {'builtin.gratitude'});
    expect(find.text('已恢复「读书笔记」'), findsOneWidget);
    expect(builtIn('reading'), findsOneWidget);

    // 只剩一个时面板里没有“全部恢复”，恢复完这一行也随之消失。等提示条
    // 收起，免得它挡在这一行上面。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tapRow(h, restoreRow);
    expect(find.text(h.l10n.diaryTemplatesRestoreAll), findsNothing);
    await tester.tap(find.text(h.l10n.diaryTemplatesRestore));
    await settle(h);
    expect(prefs(h).hiddenBuiltIns, isEmpty);
    expect(restoreRow, findsNothing);
    await h.unmount();
  });

  testWidgets('the suggestion switch and the auto template persist', (
    tester,
  ) async {
    final h = await openPage(tester);
    await tester.tap(find.text(h.l10n.diaryTemplatesStripSwitch));
    await tester.pumpAndSettle();
    expect(prefs(h).showStrip, isFalse);

    await tester.tap(find.text(h.l10n.diaryTemplatesAutoApply));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryTemplateAutoApplyPage), findsOneWidget);
    await tester.tap(find.text(h.l10n.diaryTemplatesAutoApplyDefault));
    await tester.pumpAndSettle();
    await tester.tap(find.text('晨间日记').last);
    await tester.pumpAndSettle();
    expect(prefs(h).autoTemplateId, 'builtin.morning');

    await tester.tap(find.byTooltip(h.l10n.commonBack));
    await tester.pumpAndSettle();
    expect(find.text('晨间日记'), findsWidgets);
    await h.unmount();
  });

  testWidgets('the auto-apply row summarises time ranges and the default', (
    tester,
  ) async {
    final h = await openPage(tester);
    Finder summary(String text) => find.descendant(
      of: find.byType(DiaryTemplatesSettingsGroup),
      matching: find.text(text),
    );
    expect(summary(h.l10n.diaryTemplatesAutoApplyNone), findsOneWidget);

    const rule = DiaryTemplateAutoRule(
      startMinute: 420,
      endMinute: 600,
      templateId: 'builtin.daily',
    );
    final rulesOnly = DiaryTemplatePrefs.defaults.withAutoRules([
      rule,
      rule.copyWith(startMinute: 1320, endMinute: 120),
    ]);
    await h.settings.setDiaryTemplatePrefsRaw(rulesOnly.encode());
    await tester.pumpAndSettle();
    expect(summary('2 个时间段'), findsOneWidget);

    await h.settings.setDiaryTemplatePrefsRaw(
      rulesOnly.withAuto('builtin.morning').encode(),
    );
    await tester.pumpAndSettle();
    expect(summary('2 个时间段 · 其他时间用「晨间日记」'), findsOneWidget);

    await h.settings.setDiaryTemplatePrefsRaw(
      DiaryTemplatePrefs.defaults.withAuto('builtin.morning').encode(),
    );
    await tester.pumpAndSettle();
    expect(summary('晨间日记'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('template codes go through the clipboard', (tester) async {
    String? clipboard = encodeDiaryTemplateCode(
      const DiaryTemplate(id: '', name: '导入的模板'),
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, Object?>{'text': clipboard};
        }
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final h = await openPage(tester);

    await tester.tap(find.byTooltip(h.l10n.diaryTemplatesImport));
    await tester.pumpAndSettle();
    await h.settle();
    await tester.pumpAndSettle();
    expect(find.text('已导入「导入的模板」'), findsOneWidget);
    expect(find.text('导入的模板'), findsOneWidget);

    await menu(h, builtIn('weekly'), h.l10n.diaryTemplatesCopyCode);
    expect(clipboard, startsWith('jotsy-template:v2:'));
    expect(find.text(h.l10n.diaryTemplatesCodeCopied), findsOneWidget);
    await h.unmount();
  });
}
