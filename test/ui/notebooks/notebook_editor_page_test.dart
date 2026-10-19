import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_editor_page.dart';
import 'package:node_diary/ui/widgets/color_palette_families.dart';
import 'package:node_diary/ui/widgets/color_swatch_button.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 日记本编辑页：新建与编辑写库、名称为空不能保存、未保存改动返回确认、
/// 智能日记本不显示隐私。
void main() {
  /// 首页是一个按钮，点它推入编辑页并记下返回值。
  /// [seed] 写入初始数据，返回要编辑的日记本 id（null 为新建）。
  Future<(DiaryDraftsHarness, List<String?>)> open(
    WidgetTester tester, {
    Future<String?> Function(DiaryDraftsHarness h)? seed,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    final notebookId = await seed?.call(h);
    final results = <String?>[];
    await h.pump(
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async => results.add(
              await Navigator.of(
                context,
              ).push(NotebookEditorPage.route(notebookId: notebookId)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settleAll();
    return (h, results);
  }

  Finder scrollable() => find.byType(Scrollable).first;

  Future<void> tapVisible(DiaryDraftsHarness h, Finder finder) async {
    await h.tester.scrollUntilVisible(finder, 200, scrollable: scrollable());
    await h.tester.pumpAndSettle();
    await h.tester.tap(finder);
    await h.tester.pumpAndSettle();
  }

  TextButton saveButton(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, '保存'));

  testWidgets('creates a manual notebook with the chosen settings', (
    tester,
  ) async {
    final (h, results) = await open(tester);
    expect(find.text('新建日记本'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '  旅行  ');
    await tester.pump();

    await tapVisible(h, find.byIcon(FontAwesomeIcons.plane.data));
    // 色系一排之后是当前色系（第一个色系）的具体颜色：选第二个。
    final swatches = find.byType(ColorSwatchButton);
    final second = kColorPaletteFamilies.length + 1;
    await h.tester.scrollUntilVisible(
      swatches.at(second),
      200,
      scrollable: scrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(swatches.at(second));
    await tester.pumpAndSettle();
    await tapVisible(h, find.text('不在全部日记中显示'));
    await tapVisible(h, find.text('发表时间 旧→新'));

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();

    final row = (await h.shelf()).single;
    expect(results, <String?>[row.notebookId]);
    expect(row.name, '旅行');
    expect(row.notebookKind, NotebookKind.manual);
    expect(row.notebookVisibility, NotebookVisibility.hidden);
    final payload = row.parsedPayload;
    expect(payload.icon, 'plane');
    expect(payload.color, kColorPaletteFamilies.first.colors[1].toARGB32());
    expect(payload.sort, NotebookSort.createdAsc);
    expect(payload.templateId, isNull);
    await h.unmount();
  });

  testWidgets('save is disabled while the name is empty', (tester) async {
    final (h, _) = await open(tester);
    expect(saveButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, '读书');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);
    await h.unmount();
  });

  testWidgets('back with unsaved changes asks first', (tester) async {
    final (h, results) = await open(tester);
    await tester.enterText(find.byType(TextField).first, '旅行');
    await tester.pump();
    await tester.tap(find.byTooltip(h.l10n.commonBack));
    await tester.pumpAndSettle();
    expect(find.text(h.l10n.autoT0131), findsOneWidget);

    await tester.tap(find.text(h.l10n.commonCancel).last);
    await tester.pumpAndSettle();
    expect(find.byType(NotebookEditorPage), findsOneWidget);

    await tester.tap(find.byTooltip(h.l10n.commonBack));
    await tester.pumpAndSettle();
    await tester.tap(find.text(h.l10n.autoT0132));
    await h.settleAll();
    expect(find.byType(NotebookEditorPage), findsNothing);
    expect(results, <String?>[null]);
    expect(await h.shelf(), isEmpty);
    await h.unmount();
  });

  testWidgets('smart type hides privacy and saves as normal', (tester) async {
    final (h, _) = await open(tester);
    await tester.enterText(find.byType(TextField).first, '有照片的');
    await tester.pump();
    await h.tester.scrollUntilVisible(
      find.text('隐私'),
      200,
      scrollable: scrollable(),
    );
    await tapVisible(h, find.text('智能'));
    expect(find.text('规则：保存后在这里设置条件'), findsOneWidget);
    await h.tester.scrollUntilVisible(
      find.text('默认排序'),
      200,
      scrollable: scrollable(),
    );
    expect(find.text('隐私'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();
    final row = (await h.shelf()).single;
    expect(row.notebookKind, NotebookKind.smart);
    expect(row.notebookVisibility, NotebookVisibility.normal);
    await h.unmount();
  });

  testWidgets('edits an existing notebook and keeps fields it does not show', (
    tester,
  ) async {
    late String id;
    final chapter = NotebookChapter(id: 'ch000001', title: '第一章');
    final (h, results) = await open(
      tester,
      seed: (h) async => id = await h.notebook(
        '旅行',
        visibility: NotebookVisibility.locked,
        payload: NotebookPayload(
          description: '去过的地方',
          icon: 'heart',
          chapters: <NotebookChapter>[chapter],
          sort: NotebookSort.book,
        ),
      ),
    );

    expect(find.text('编辑日记本'), findsOneWidget);
    expect(find.text('旅行'), findsWidgets);
    expect(find.text('去过的地方'), findsOneWidget);
    // 编辑时不能改类型。
    expect(find.text('类型'), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField).first, '远方');
    await tester.pump();
    await tapVisible(h, find.text('正常'));
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();

    expect(results, <String?>[id]);
    final row = (await h.notebookRow(id))!;
    expect(row.name, '远方');
    expect(row.notebookVisibility, NotebookVisibility.normal);
    final payload = row.parsedPayload;
    expect(payload.description, '去过的地方');
    expect(payload.icon, 'heart');
    expect(payload.chapters, <NotebookChapter>[chapter]);
    expect(payload.sort, NotebookSort.book);
    await h.unmount();
  });
}
