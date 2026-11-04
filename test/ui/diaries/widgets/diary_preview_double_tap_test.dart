import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_body.dart';

import '../../../support/expressive_test_theme.dart';

Map<String, Object?> _block(String type, String text) => {
  'type': type,
  'data': {
    'delta': [
      {'insert': text},
    ],
  },
};

/// 预览页正文的双击：双击文字交出双击处的文字位置；单击、慢的两次点按、
/// 双击列表标记与图片都不算。
void main() {
  final hits = <Position>[];
  setUp(hits.clear);

  Future<DiaryEditorController> pump(WidgetTester tester) async {
    final controller = DiaryEditorController.fromContent(
      jsonEncode({
        'document': {
          'type': 'page',
          'children': [
            _block('paragraph', 'Short'),
            _block('paragraph', 'Second paragraph text'),
            _block('bulleted_list', 'Bullet item'),
          ],
        },
      }),
      readOnly: true,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle()),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DiaryPreviewBody(
                controller: controller,
                appearance: const DiaryTextAppearance(
                  typography: DiaryTypography(),
                ),
                onOpenImage: (_, _) {},
                onDoubleTapText: hits.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Rect textRect(WidgetTester tester, String text) =>
      tester.getRect(find.text(text, findRichText: true).first);

  Future<void> doubleTapAt(WidgetTester tester, Offset position) async {
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(position);
    await tester.pump();
    // 双击处理放在微任务里（等上游的双击选词完成）。
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('double-tapping text reports that block and character', (
    tester,
  ) async {
    final controller = await pump(tester);
    final rect = textRect(tester, 'Second paragraph text');

    await doubleTapAt(tester, rect.centerLeft + const Offset(2, 0));

    expect(hits, hasLength(1));
    expect(hits.single.path, <int>[1]);
    expect(hits.single.offset, 0);
    // 上游双击选中的词已清掉：回到预览页时不留选区。
    expect(controller.state.selection, isNull);
  });

  testWidgets('the blank tail of a short line lands at its end', (
    tester,
  ) async {
    await pump(tester);
    final rect = textRect(tester, 'Short');
    final tail = Offset(
      tester.getSize(find.byType(Scaffold)).width - 24,
      rect.center.dy,
    );

    await doubleTapAt(tester, tail);

    expect(hits, hasLength(1));
    expect(hits.single.path, <int>[0]);
    expect(hits.single.offset, 'Short'.length);
  });

  testWidgets('double-tapping a list marker does not count', (tester) async {
    await pump(tester);
    final rect = textRect(tester, 'Bullet item');

    await doubleTapAt(tester, rect.centerLeft - const Offset(12, 0));
    expect(hits, isEmpty);

    await doubleTapAt(tester, rect.center);
    expect(hits.single.path, <int>[2]);
  });

  testWidgets('a single tap and two slow taps do not count', (tester) async {
    await pump(tester);
    final point = textRect(tester, 'Second paragraph text').center;

    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 400));
    expect(hits, isEmpty);

    final gesture = await tester.createGesture();
    await gesture.down(point, timeStamp: const Duration(seconds: 10));
    await gesture.up(timeStamp: const Duration(seconds: 10, milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.down(point, timeStamp: const Duration(seconds: 11));
    await gesture.up(timeStamp: const Duration(seconds: 11, milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    expect(hits, isEmpty);
  });

  testWidgets('a drag between taps does not count', (tester) async {
    await pump(tester);
    final point = textRect(tester, 'Second paragraph text').center;

    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.dragFrom(point, const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 400));
    expect(hits, isEmpty);
  });

  test('text positions are clamped into the block', () {
    final document = af.Document.blank(withInitialText: true);
    document.root.children.first.updateAttributes({
      'delta': (af.Delta()..insert('abc')).toJson(),
    });
    expect(
      DiaryEditorController.collapsedSelectionAt(
        document,
        af.Position(path: const [0], offset: 9),
      ),
      af.Selection.collapsed(af.Position(path: const [0], offset: 3)),
    );
    expect(
      DiaryEditorController.collapsedSelectionAt(
        document,
        af.Position(path: const [4], offset: 0),
      ),
      isNull,
    );
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
