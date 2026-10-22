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
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_markers.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';

import '../../../support/expressive_test_theme.dart';

Map<String, Object?> _block(
  String type,
  String text, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  if (children.isNotEmpty) 'children': children,
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
    ...data,
  },
};

String _document(List<Map<String, Object?>> children) => jsonEncode({
  'document': {'type': 'page', 'children': children},
});

void main() {
  const appearance = DiaryTextAppearance(typography: DiaryTypography());

  Future<void> pump(
    WidgetTester tester,
    DiaryEditorController controller, {
    bool todoToggle = false,
    String? placeholder,
  }) async {
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
            body: DiaryEditor(
              controller: controller,
              appearance: appearance,
              todoToggle: todoToggle,
              placeholder: placeholder,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bullets rotate shape by nesting level', (tester) async {
    final controller = DiaryEditorController.fromContent(
      _document([
        _block(
          'bulleted_list',
          'a',
          children: [
            _block(
              'bulleted_list',
              'b',
              children: [_block('bulleted_list', 'c')],
            ),
          ],
        ),
      ]),
    );
    await pump(tester, controller);
    BoxDecoration markOf(String text) {
      final marker = find.byWidgetPredicate(
        (widget) =>
            widget is DiaryBulletMarker &&
            widget.node.delta?.toPlainText() == text,
      );
      final container = tester.widget<Container>(
        find.descendant(of: marker, matching: find.byType(Container)).last,
      );
      return container.decoration! as BoxDecoration;
    }

    // 第一层实心圆、第二层空心圆、第三层小方块。
    expect(markOf('a').shape, BoxShape.circle);
    expect(markOf('a').border, isNull);
    expect(markOf('b').shape, BoxShape.circle);
    expect(markOf('b').border, isNotNull);
    expect(markOf('c').shape, BoxShape.rectangle);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('numbered lists continue by sibling and rotate by level', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      _document([
        _block('numbered_list', 'one'),
        _block(
          'numbered_list',
          'two',
          children: [
            _block('numbered_list', 'two-a'),
            _block(
              'numbered_list',
              'two-b',
              children: [
                _block('numbered_list', 'two-b-i'),
                _block('numbered_list', 'two-b-ii'),
              ],
            ),
          ],
        ),
        _block('paragraph', 'break'),
        _block('numbered_list', 'restart', data: {'number': 5}),
      ]),
    );
    await pump(tester, controller);
    for (final label in ['1.', '2.', 'a.', 'b.', 'i.', 'ii.', '5.']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('a todo checkbox toggles with undo and stays read-only', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      _document([
        _block('todo_list', 'task', data: {'checked': false}),
      ]),
    );
    await pump(tester, controller);
    final box = find.byType(DiaryTodoCheckbox);
    // 标记格与首行同高，复选框不会把这一行撑高。
    expect(
      tester.getSize(box).height,
      closeTo(
        appearance.typography.fontSize * appearance.typography.lineHeight,
        0.5,
      ),
    );
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(controller.document.nodeAtPath([0])!.attributes['checked'], isTrue);
    expect(tester.widget<DiaryTodoCheckbox>(box).checked, isTrue);
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.document.nodeAtPath([0])!.attributes['checked'], isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();

    final readOnly = DiaryEditorController.fromContent(
      _document([
        _block('todo_list', 'task', data: {'checked': false}),
      ]),
      readOnly: true,
    );
    await pump(tester, readOnly);
    expect(tester.widget<DiaryTodoCheckbox>(box).onToggle, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    readOnly.dispose();
  });

  testWidgets('placeholders match the page, the caret line and headings', (
    tester,
  ) async {
    const hint = '开始记录…';
    const slashHint = '输入 / 插入区块';
    final empty = DiaryEditorController.fromContent('');
    empty.select(af.Selection.collapsed(af.Position(path: [0])));
    await pump(tester, empty, placeholder: hint);
    // 整篇只有一个空段落：页面的占位。
    expect(find.text(hint, findRichText: true), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    empty.dispose();

    final mixed = DiaryEditorController.fromContent(
      _document([
        _block('paragraph', 'text'),
        _block('paragraph', ''),
        _block('heading', '', data: {'level': 2}),
      ]),
    );
    mixed.select(af.Selection.collapsed(af.Position(path: [1])));
    await pump(tester, mixed, placeholder: hint);
    // 正文中间光标所在的空行提示 / 命令，不再是“开始记录…”。
    expect(find.text(hint, findRichText: true), findsNothing);
    expect(find.text(slashHint, findRichText: true), findsOneWidget);
    // 空标题写出自己的级别。
    expect(find.text('二级标题', findRichText: true), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    mixed.dispose();

    final readOnly = DiaryEditorController.fromContent(
      _document([_block('paragraph', 'text'), _block('paragraph', '')]),
      readOnly: true,
    );
    readOnly.select(af.Selection.collapsed(af.Position(path: [1])));
    await pump(tester, readOnly, placeholder: hint);
    expect(find.text(slashHint, findRichText: true), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    readOnly.dispose();
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
