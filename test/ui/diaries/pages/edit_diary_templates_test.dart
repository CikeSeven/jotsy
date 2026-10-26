import '../../../support/diary_content_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_built_ins.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_prefs.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_auto_rule.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_selection.dart';
import 'package:node_diary/ui/diary_templates/providers/diary_template_providers.dart';
import 'package:node_diary/ui/diary_templates/widgets/diary_template_strip.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../../support/fake_day_photo_library.dart';

/// 新建空白日记的模板建议条：点一下套用、可撤销；只套用不动的内容不算
/// 草稿；自动套用与新建入口带来的模板在打开时就套上。
void main() {
  Finder titleField() => find.byType(TextField).first;
  Finder strip() => find.byType(DiaryTemplateStrip);
  Finder stripTitle(DiaryDraftsHarness h) =>
      find.text(h.l10n.diaryTemplateStripTitle);

  String titleText(WidgetTester tester) =>
      tester.widget<TextField>(titleField()).controller!.text;

  /// 正文由 Quill 以富文本绘制，不是 Text：直接读文档。
  String bodyText(WidgetTester tester) => tester
      .widget<DiaryEditor>(find.byType(DiaryEditor))
      .controller
      .document
      .toPlainText();

  String todayDaily(DateTime day) =>
      '${DateFormat.yMMMMd('zh').format(day)} '
      '${DateFormat.EEEE('zh').format(day)}';

  /// 每个用例只建一次环境：同一测试里重复 pumpWidget 新的 ProviderScope
  /// 会沿用旧容器，换不掉设置服务的 override。
  Future<DiaryDraftsHarness> openEditor(
    WidgetTester tester, {
    DiaryDraftsHarness? harness,
    String? draftId,
    DateTime? day,
    DiaryTemplateSelection? template,
    String? prefsRaw,
    DateTime? now,
  }) async {
    final h = harness ?? await DiaryDraftsHarness.create(tester);
    if (prefsRaw != null) {
      await h.settings.setDiaryTemplatePrefsRaw(prefsRaw);
    }
    await h.pump(
      EditDiaryPage(
        entryMode: EditDiaryEntryMode.create,
        createDraftId: draftId,
        createDateOverride: day,
        createTemplate: template,
      ),
      overrides: [
        dayPhotoLibraryProvider.overrideWithValue(
          FakeDayPhotoLibrary(access: DayPhotoAccess.denied),
        ),
        if (now != null)
          diaryTemplateClockProvider.overrideWithValue(() => now),
      ],
    );
    await h.settle();
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> waitForDebouncedSave(DiaryDraftsHarness h) async {
    await h.tester.pump(const Duration(milliseconds: 1400));
    await h.settle();
  }

  /// 建议条横向滚动：先把这个模板滚进视野再点。
  Future<void> tapSuggestion(DiaryDraftsHarness h, String name) async {
    final chip = find.descendant(of: strip(), matching: find.text(name));
    await h.tester.ensureVisible(chip);
    await h.tester.pumpAndSettle();
    await h.tester.tap(chip);
    await h.settle();
    await h.tester.pumpAndSettle();
  }

  Future<void> closeSnackBar(DiaryDraftsHarness h) async {
    await h.tester.pump(const Duration(seconds: 5));
    await h.tester.pumpAndSettle();
  }

  testWidgets('tapping a suggestion applies it and undo brings back a blank '
      'entry', (tester) async {
    final h = await openEditor(tester);
    expect(stripTitle(h), findsOneWidget);

    await tapSuggestion(h, '每日记录');

    expect(titleText(tester), todayDaily(DateTime.now()));
    expect(bodyText(tester), contains('今天的故事'));
    expect(stripTitle(h), findsNothing);
    expect(find.text('已套用「每日记录」'), findsOneWidget);

    await tester.tap(find.text(h.l10n.commonUndo));
    await tester.pumpAndSettle();
    await h.settle();
    await tester.pumpAndSettle();

    expect(titleText(tester), isEmpty);
    expect(bodyText(tester), isNot(contains('今天的故事')));
    expect(stripTitle(h), findsOneWidget);
    await h.unmount();
  });

  testWidgets('an applied template left untouched is not saved as a draft, '
      'typing makes it one', (tester) async {
    final h = await openEditor(tester);
    await tapSuggestion(h, '每日记录');
    await waitForDebouncedSave(h);
    expect(await h.drafts(), isEmpty);

    await tester.enterText(titleField(), '改过的标题');
    await waitForDebouncedSave(h);
    expect((await h.drafts()).map((row) => row.title), ['改过的标题']);

    // 改回模板原样又不算了：这一份随之删除。
    await tester.enterText(titleField(), todayDaily(DateTime.now()));
    await waitForDebouncedSave(h);
    expect(await h.drafts(), isEmpty);
    await closeSnackBar(h);
    await h.unmount();
  });

  testWidgets('undo does nothing once the user has started writing', (
    tester,
  ) async {
    final h = await openEditor(tester);
    await tapSuggestion(h, '每日记录');

    await tester.enterText(titleField(), '已经开始写了');
    await tester.pump();
    await tester.tap(find.text(h.l10n.commonUndo));
    await tester.pumpAndSettle();
    await h.settle();

    expect(titleText(tester), '已经开始写了');
    expect(bodyText(tester), contains('今天的故事'));
    await h.unmount();
  });

  testWidgets('typing before choosing a template hides the strip', (
    tester,
  ) async {
    final h = await openEditor(tester);
    await tester.enterText(titleField(), '自己写');
    await tester.pumpAndSettle();
    expect(stripTitle(h), findsNothing);

    await tester.enterText(titleField(), '');
    await tester.pumpAndSettle();
    expect(stripTitle(h), findsNothing, reason: '写过之后不再出现');
    await h.unmount();
  });

  testWidgets('no strip when continuing a draft', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    final draft = await h.seed('旧草稿', updatedAt: DateTime(2026, 10, 1));
    await openEditor(tester, harness: h, draftId: draft);
    expect(titleText(tester), '旧草稿');
    expect(find.byType(DiaryTemplateStrip), findsOneWidget);
    expect(stripTitle(h), findsNothing);
    await h.unmount();
  });

  testWidgets('no strip when it is turned off', (tester) async {
    final h = await openEditor(tester, prefsRaw: '{"v":1,"strip":false}');
    expect(stripTitle(h), findsNothing);
    await h.unmount();
  });

  testWidgets('the auto template is applied on open with an undo', (
    tester,
  ) async {
    final h = await openEditor(
      tester,
      prefsRaw: '{"v":1,"auto":"builtin.gratitude"}',
    );
    await tester.pumpAndSettle();

    expect(titleText(tester), startsWith('感恩 · '));
    expect(find.text('已自动套用「感恩日记」'), findsOneWidget);
    final tags = (await tester.runAsync(
      () => h.database.watchAllTags().first,
    ))!;
    expect(tags.map((tag) => tag.name), ['感恩']);
    // 自动套用不计入最近使用。
    expect(
      DiaryTemplatePrefs.decode(h.settings.diaryTemplatePrefsRaw).recent,
      isEmpty,
    );

    await tester.tap(find.text(h.l10n.commonUndo));
    await tester.pumpAndSettle();
    await h.settle();
    expect(titleText(tester), isEmpty);
    final after = (await tester.runAsync(
      () => h.database.watchAllTags().first,
    ))!;
    expect(after, isEmpty, reason: '为模板新建、没人用的标签随撤销回收');
    await h.unmount();
  });

  testWidgets('a template chosen at the entry is applied without a hint and '
      'counts as recently used', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    final reading = buildBuiltInDiaryTemplates(
      h.l10n,
    ).firstWhere((t) => t.id == 'builtin.reading');
    await h.pump(
      EditDiaryPage(
        entryMode: EditDiaryEntryMode.create,
        createTemplate: DiaryTemplateSelection(reading),
      ),
    );
    await h.settle();
    await tester.pumpAndSettle();

    expect(titleText(tester), startsWith('读书笔记 · '));
    expect(find.byType(SnackBar), findsNothing);
    expect(DiaryTemplatePrefs.decode(h.settings.diaryTemplatePrefsRaw).recent, [
      'builtin.reading',
    ]);
    await h.unmount();
  });

  testWidgets('date variables follow the backfilled day', (tester) async {
    final h = await openEditor(tester, day: DateTime(2026, 3, 5));
    await tapSuggestion(h, '每日记录');

    expect(titleText(tester), '2026年3月5日 星期四');
    await closeSnackBar(h);
    await h.unmount();
  });

  group('auto-apply by time range', () {
    // 早上 7–10 点用晨间日记，其他时间用感恩日记；还有一条指向已删除模板的
    // 午间规则，命中时应落到默认模板。
    final prefs = DiaryTemplatePrefs(autoTemplateId: 'builtin.gratitude')
        .withAutoRules(const [
          DiaryTemplateAutoRule(
            startMinute: 7 * 60,
            endMinute: 10 * 60,
            templateId: 'builtin.morning',
          ),
          DiaryTemplateAutoRule(
            startMinute: 12 * 60,
            endMinute: 13 * 60,
            templateId: 'deleted-template',
          ),
        ])
        .encode();

    testWidgets('a blank entry inside a range gets that range\'s template', (
      tester,
    ) async {
      final h = await openEditor(
        tester,
        prefsRaw: prefs,
        now: DateTime(2026, 10, 19, 8, 30),
      );
      expect(find.text('已自动套用「晨间日记」'), findsOneWidget);
      await closeSnackBar(h);
      await h.unmount();
    });

    testWidgets('outside every range the default template is used', (
      tester,
    ) async {
      final h = await openEditor(
        tester,
        prefsRaw: prefs,
        now: DateTime(2026, 10, 19, 15),
      );
      expect(find.text('已自动套用「感恩日记」'), findsOneWidget);
      await closeSnackBar(h);
      await h.unmount();
    });

    testWidgets('a range pointing at a deleted template falls back to the '
        'default', (tester) async {
      final h = await openEditor(
        tester,
        prefsRaw: prefs,
        now: DateTime(2026, 10, 19, 12, 30),
      );
      expect(find.text('已自动套用「感恩日记」'), findsOneWidget);
      await closeSnackBar(h);
      await h.unmount();
    });

    testWidgets('backfilling another day ignores the ranges', (tester) async {
      final h = await openEditor(
        tester,
        prefsRaw: prefs,
        now: DateTime(2026, 10, 19, 8, 30),
        day: DateTime(2026, 10, 18),
      );
      expect(find.text('已自动套用「感恩日记」'), findsOneWidget);
      await closeSnackBar(h);
      await h.unmount();
    });
  });
}
