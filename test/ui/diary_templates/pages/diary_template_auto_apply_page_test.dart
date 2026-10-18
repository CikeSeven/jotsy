import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_auto_rule.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_prefs.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_auto_apply_page.dart';

import '../../../support/diary_drafts_harness.dart';

/// 自动套用页：添加、编辑、删除（可撤销）时间段，选默认模板，上限与窄屏。
///
/// 时间都按 24 小时制显示与输入（测试里固定系统设置），时间选择器切到
/// 文字输入再填时与分，比拨表盘稳定。
void main() {
  Future<DiaryDraftsHarness> openPage(
    WidgetTester tester, {
    DiaryTemplatePrefs prefs = DiaryTemplatePrefs.defaults,
    Size size = const Size(400, 900),
  }) async {
    tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
    addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = size;
    final raw = prefs.encode();
    if (raw != null) await h.settings.setDiaryTemplatePrefsRaw(raw);
    await h.pump(const DiaryTemplateAutoApplyPage());
    await tester.pumpAndSettle();
    return h;
  }

  DiaryTemplatePrefs prefs(DiaryDraftsHarness h) =>
      DiaryTemplatePrefs.decode(h.settings.diaryTemplatePrefsRaw);

  Future<void> tapAndSettle(DiaryDraftsHarness h, Finder finder) async {
    await h.tester.ensureVisible(finder);
    await h.tester.pumpAndSettle();
    await h.tester.tap(finder);
    await h.tester.pumpAndSettle();
    await h.settle();
    await h.tester.pumpAndSettle();
  }

  /// 点开始或结束按钮，在时间选择器里切到文字输入并填入时间。
  Future<void> pickTime(
    DiaryDraftsHarness h,
    String buttonLabel,
    int hour,
    int minute,
  ) async {
    final tester = h.tester;
    await tester.tap(find.text(buttonLabel));
    await tester.pumpAndSettle();
    final dialog = find.byType(TimePickerDialog);
    final material = MaterialLocalizations.of(tester.element(dialog));
    await tester.tap(find.byTooltip(material.inputTimeModeButtonLabel));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '$hour');
    await tester.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
    await tester.tap(find.text(material.okButtonLabel));
    await tester.pumpAndSettle();
  }

  Finder saveButton(DiaryDraftsHarness h) =>
      find.widgetWithText(FilledButton, h.l10n.commonSave);

  const weekend = DiaryTemplateAutoRule(
    startMinute: 7 * 60,
    endMinute: 10 * 60,
    weekdays: {6, 7},
    templateId: 'builtin.weekly',
  );

  testWidgets('adds an overnight Sunday rule through the sheet', (
    tester,
  ) async {
    final h = await openPage(tester);
    await tapAndSettle(h, find.text(h.l10n.diaryTemplatesAutoApplyAddRule));
    expect(find.text('07:00'), findsOneWidget, reason: '新规则默认 07:00–10:00');
    expect(find.text('10:00'), findsOneWidget);

    await pickTime(h, h.l10n.diaryTemplatesAutoApplyStart, 22, 0);
    await pickTime(h, h.l10n.diaryTemplatesAutoApplyEnd, 2, 0);
    expect(find.text('跨夜，到次日 02:00 结束'), findsOneWidget);
    await tester.tap(find.text('周日'));
    await tester.pumpAndSettle();
    await tapAndSettle(h, saveButton(h));

    expect(prefs(h).autoRules, const [
      DiaryTemplateAutoRule(
        startMinute: 22 * 60,
        endMinute: 2 * 60,
        weekdays: {7},
        templateId: 'builtin.daily',
      ),
    ]);
    expect(find.text('22:00 – 次日 02:00'), findsOneWidget);
    expect(find.text('周日 · 每日记录'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('the same start and end time cannot be saved', (tester) async {
    final h = await openPage(tester);
    await tapAndSettle(h, find.text(h.l10n.diaryTemplatesAutoApplyAddRule));
    await pickTime(h, h.l10n.diaryTemplatesAutoApplyEnd, 7, 0);

    expect(find.text(h.l10n.diaryTemplatesAutoApplySameTime), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton(h)).onPressed, isNull);
    await h.unmount();
  });

  testWidgets('editing a rule replaces it with the new template', (
    tester,
  ) async {
    final h = await openPage(
      tester,
      prefs: DiaryTemplatePrefs.defaults.withAutoRules([weekend]),
    );
    expect(find.text('周末 · 周回顾'), findsOneWidget);

    await tapAndSettle(h, find.text('07:00 – 10:00'));
    expect(find.text(h.l10n.diaryTemplatesAutoApplyEditRule), findsOneWidget);
    await tapAndSettle(h, find.text(h.l10n.diaryTemplatesAutoApplyTemplate));
    expect(
      find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.text(h.l10n.diaryTemplatesAutoApplyNone),
      ),
      findsNothing,
      reason: '时间段必须指向一个模板',
    );
    await tapAndSettle(h, find.text('晨间日记').last);
    await tapAndSettle(h, saveButton(h));

    expect(prefs(h).autoRules, [
      weekend.copyWith(templateId: 'builtin.morning'),
    ]);
    expect(find.text('周末 · 晨间日记'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('deleting a rule can be undone', (tester) async {
    final h = await openPage(
      tester,
      prefs: DiaryTemplatePrefs.defaults.withAutoRules([weekend]),
    );
    await tapAndSettle(h, find.text('07:00 – 10:00'));
    await tapAndSettle(h, find.text(h.l10n.commonDelete));

    expect(prefs(h).autoRules, isEmpty);
    expect(find.text('07:00 – 10:00'), findsNothing);
    expect(
      find.text(h.l10n.diaryTemplatesAutoApplyRuleDeleted),
      findsOneWidget,
    );

    await tapAndSettle(h, find.text(h.l10n.commonUndo));
    expect(prefs(h).autoRules, [weekend]);
    expect(find.text('07:00 – 10:00'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('the default template is chosen in the shared sheet', (
    tester,
  ) async {
    final h = await openPage(tester);
    await tapAndSettle(h, find.text(h.l10n.diaryTemplatesAutoApplyDefault));
    expect(find.text(h.l10n.diaryTemplatesAutoApplyHint), findsOneWidget);
    await tapAndSettle(h, find.text('感恩日记').last);

    expect(prefs(h).autoTemplateId, 'builtin.gratitude');
    expect(find.text('感恩日记'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('adding is disabled at twelve rules', (tester) async {
    final h = await openPage(
      tester,
      prefs: DiaryTemplatePrefs.defaults.withAutoRules([
        for (var i = 0; i < DiaryTemplatePrefs.maxAutoRules; i++)
          DiaryTemplateAutoRule(
            startMinute: i * 60,
            endMinute: i * 60 + 30,
            templateId: 'builtin.daily',
          ),
      ]),
    );
    final add = find.byKey(const ValueKey<String>('auto_rule_add'));
    await tester.scrollUntilVisible(add, 300);
    expect(tester.widget<ListTile>(add).enabled, isFalse);
    expect(find.text('最多 12 个时间段'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('page and sheet fit 320dp at 1.3x text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = await openPage(
      tester,
      size: const Size(320, 700),
      prefs: DiaryTemplatePrefs(autoTemplateId: 'builtin.gratitude')
          .withAutoRules([
            weekend,
            const DiaryTemplateAutoRule(
              startMinute: 22 * 60,
              endMinute: 2 * 60,
              weekdays: {1, 3, 5},
              templateId: 'builtin.evening',
            ),
            const DiaryTemplateAutoRule(
              startMinute: 12 * 60,
              endMinute: 13 * 60,
              templateId: 'gone',
            ),
          ]),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining(h.l10n.diaryTemplatesAutoApplyMissing),
      findsOneWidget,
    );

    await tapAndSettle(h, find.text('22:00 – 次日 02:00'));
    expect(tester.takeException(), isNull);
    expect(find.text(h.l10n.diaryTemplatesAutoApplyEditRule), findsOneWidget);
    await h.unmount();
  });
}
