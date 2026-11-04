import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/controllers/diary_open_flow.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_behavior.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';

import '../../../support/diary_drafts_harness.dart';

const _body = 'Double tap lands the caret here';

/// 预览页双击正文进入编辑：编辑页打开后光标停在双击处并获得焦点；阅读行为
/// 关闭或在桌面上时双击不进入编辑。
void main() {
  Future<void> openPreview(DiaryDraftsHarness h) async {
    final diaryId = (await h.tester.runAsync(
      () => h.database.createDiary(
        title: 'Seeded diary',
        contentDocJson: '[{"insert":"$_body\\n"}]',
        contentText: _body,
        metadataJson: '{}',
        createdAtOverride: DateTime(2026, 10, 1),
      ),
    ))!;
    await h.pump(
      Consumer(
        builder: (context, ref, _) {
          ref.watch(settingsServiceProvider);
          return Scaffold(
            body: TextButton(
              onPressed: () => openDiaryPage(context, ref, diaryId: diaryId),
              child: const Text('Open'),
            ),
          );
        },
      ),
    );
    await h.tester.tap(find.text('Open'));
    await h.settle();
    await h.tester.pumpAndSettle();
    expect(find.byType(DiaryPreviewPage), findsOneWidget);
  }

  /// 编辑器获得焦点后光标闪烁，pumpAndSettle 不会结束：固定出帧。
  Future<void> pumpFrames(WidgetTester tester, DiaryDraftsHarness h) async {
    await h.settle();
    for (var frame = 0; frame < 16; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> doubleTapBody(WidgetTester tester, DiaryDraftsHarness h) async {
    final text = find.descendant(
      of: find.byType(DiaryPreviewPage),
      matching: find.text(_body, findRichText: true),
    );
    // 落在第 8 个字（“Double t” 之后那个字）的左半边。
    final paragraph = tester.renderObject<RenderParagraph>(text.first);
    const position = TextPosition(offset: 8);
    final caret = paragraph.getOffsetForCaret(position, Rect.zero);
    final lineHeight = paragraph.getFullHeightForCaret(position);
    final point = paragraph.localToGlobal(caret + Offset(2, lineHeight / 2));
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(point);
    await pumpFrames(tester, h);
  }

  DiaryEditor editorIn(WidgetTester tester) => tester.widget<DiaryEditor>(
    find.descendant(
      of: find.byType(EditDiaryPage),
      matching: find.byType(DiaryEditor),
    ),
  );

  testWidgets('double-tapping the body opens the editor at that spot', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await openPreview(h);

    await doubleTapBody(tester, h);

    final page = tester.widget<EditDiaryPage>(find.byType(EditDiaryPage));
    expect(page.entryMode, EditDiaryEntryMode.edit);
    final caret = page.initialCaret!;
    expect(caret.path, <int>[0]);
    expect(caret.offset, 8);

    final editor = editorIn(tester);
    final selection = editor.controller.selection!;
    expect(selection.isCollapsed, isTrue);
    expect(selection.end, caret);
    expect(editor.focusNode!.hasFocus, isTrue);
    await h.unmount();
  });

  testWidgets('the edit button still opens the editor without a caret', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await openPreview(h);

    await tester.tap(find.byTooltip(h.l10n.commonEdit));
    await pumpFrames(tester, h);

    expect(
      tester.widget<EditDiaryPage>(find.byType(EditDiaryPage)).initialCaret,
      isNull,
    );
    expect(editorIn(tester).focusNode!.hasFocus, isFalse);
    await h.unmount();
  });

  testWidgets('with the reading behavior off a double tap stays in preview', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await tester.runAsync(
      () => h.settings.setDiaryPreviewStyleRaw(
        const DiaryPreviewSettings(
          behavior: DiaryPreviewBehavior(doubleTapToEdit: false),
        ).encode(),
      ),
    );
    await openPreview(h);

    await doubleTapBody(tester, h);

    expect(find.byType(EditDiaryPage), findsNothing);
    await h.unmount();
  });

  testWidgets('on desktop a double tap keeps selecting words', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final h = await DiaryDraftsHarness.create(tester);
      await openPreview(h);

      await doubleTapBody(tester, h);

      expect(find.byType(EditDiaryPage), findsNothing);
      await h.unmount();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('the reading behavior defaults on and round-trips', () {
    expect(DiaryPreviewBehavior.defaults.doubleTapToEdit, isTrue);
    expect(DiaryPreviewBehavior.defaults.toJson(), isEmpty);
    const off = DiaryPreviewBehavior(doubleTapToEdit: false);
    expect(off.toJson(), <String, Object>{'doubleTapToEdit': false});
    expect(DiaryPreviewBehavior.fromJson(off.toJson()), off);
    expect(
      DiaryPreviewBehavior.fromJson(<String, Object>{'doubleTapToEdit': 'x'}),
      DiaryPreviewBehavior.defaults,
    );
  });
}
