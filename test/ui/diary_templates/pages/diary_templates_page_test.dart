import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_code.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_json.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_prefs.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_editor_page.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_templates_page.dart';

import '../../../support/diary_drafts_harness.dart';

/// 模板管理页：内置模板与我的模板、复制、删除与隐藏的撤销、偏好、模板码。
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

  /// 打开某一行的“更多操作”菜单并点其中一项。
  Future<void> menu(DiaryDraftsHarness h, Finder row, String action) async {
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

  testWidgets('copying a built-in opens the editor on the new copy', (
    tester,
  ) async {
    final h = await openPage(tester);
    await menu(h, builtIn('daily'), h.l10n.diaryTemplatesCopyToMine);

    expect(find.byType(DiaryTemplateEditorPage), findsOneWidget);
    await tester.tap(find.byTooltip(h.l10n.commonBack));
    await tester.pumpAndSettle();
    await h.settle();
    await tester.pumpAndSettle();

    final rows = (await tester.runAsync(h.database.getDiaryTemplates))!;
    expect(rows.single.name, '每日记录');
    expect(mine(rows.single.templateId), findsOneWidget);
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

  testWidgets('hiding a built-in marks it and undo shows it again', (
    tester,
  ) async {
    final h = await openPage(tester);
    await menu(h, builtIn('gratitude'), h.l10n.diaryTemplatesHide);
    expect(prefs(h).hiddenBuiltIns, {'builtin.gratitude'});
    expect(
      find.descendant(
        of: builtIn('gratitude'),
        matching: find.text(h.l10n.diaryTemplateHiddenBadge),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(h.l10n.commonUndo));
    await tester.pumpAndSettle();
    await h.settle();
    expect(prefs(h).hiddenBuiltIns, isEmpty);
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
    await tester.tap(find.text('晨间日记').last);
    await tester.pumpAndSettle();
    expect(prefs(h).autoTemplateId, 'builtin.morning');
    expect(find.text('晨间日记'), findsWidgets);
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
    expect(clipboard, startsWith('jotsy-template:v1:'));
    expect(find.text(h.l10n.diaryTemplatesCodeCopied), findsOneWidget);
    await h.unmount();
  });
}
