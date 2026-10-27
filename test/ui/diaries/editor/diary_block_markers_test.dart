import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_markers.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor_styles.dart';

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

/// 正文里显示 [text] 的那段文字（上游 `AppFlowyRichText` 内的 RichText）。
RenderParagraph _paragraph(WidgetTester tester, String text) => tester
    .renderObject<RenderParagraph>(find.text(text, findRichText: true).first);

/// 文字首行基线的全局纵坐标：按这段文字自己的样式、缩放与行高规则重排读出。
double _firstBaseline(WidgetTester tester, String text) {
  final paragraph = _paragraph(tester, text);
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.size.width);
  final baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  painter.dispose();
  return paragraph.localToGlobal(Offset.zero).dy + baseline;
}

/// 标记里实际画出的方块或圆点的全局矩形。
Rect _markRect(WidgetTester tester, Finder marker) => tester.getRect(
  find.descendant(of: marker, matching: find.byType(Positioned)),
);

Finder _markerOf(Type type, String text) => find.byWidgetPredicate(
  (widget) =>
      widget.runtimeType == type &&
      switch (widget) {
        DiaryBulletMarker(:final node) ||
        DiaryNumberMarker(:final node) => node.delta?.toPlainText() == text,
        _ => false,
      },
);

void main() {
  const appearance = DiaryTextAppearance(typography: DiaryTypography());

  Future<void> pump(
    WidgetTester tester,
    DiaryEditorController controller, {
    bool todoToggle = false,
    String? placeholder,
    DiaryTextAppearance appearance = appearance,
    double textScale = 1,
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
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
      final mark = tester.widget<DecoratedBox>(
        find.descendant(of: marker, matching: find.byType(DecoratedBox)),
      );
      return mark.decoration as BoxDecoration;
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

  testWidgets('a chosen list style covers its whole run, new items included', (
    tester,
  ) async {
    // 存储的正文经 decodeStoredDiaryBlocks 读入，样式键原样保留；没有样式
    // 键的项（回车新起的）沿用同段的样式。
    final controller = DiaryEditorController.fromContent(
      _document([
        _block('numbered_list', 'one', data: {'listStyle': 'cjk'}),
        _block('numbered_list', 'two'),
        _block('numbered_list', 'three', data: {'listStyle': 'cjk'}),
        _block('paragraph', 'break'),
        _block('bulleted_list', 'star', data: {'listStyle': 'star'}),
        _block('bulleted_list', 'star too'),
        _block('bulleted_list', 'dash', data: {'listStyle': 'dash'}),
      ]),
    );
    await pump(tester, controller);
    for (final label in ['一、', '二、', '三、']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    IconData? iconOf(String text) => tester
        .widgetList<FaIcon>(
          find.descendant(
            of: _markerOf(DiaryBulletMarker, text),
            matching: find.byType(FaIcon),
          ),
        )
        .firstOrNull
        ?.icon;
    expect(iconOf('star'), FontAwesomeIcons.solidStar.data);
    expect(iconOf('star too'), FontAwesomeIcons.solidStar.data);
    // 一个文档里同类型的相邻列表就是同一段：最近的样式优先。
    expect(iconOf('dash'), isNull);
    expect(
      controller.document.root.children.first.attributes['listStyle'],
      'cjk',
    );
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
    // 标记格与单行文字同高，复选框不会把这一行撑高。
    expect(
      tester.getSize(box).height,
      closeTo(_paragraph(tester, 'task').size.height, 0.5),
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

  /// 列表与待办的标记对齐首行：圆点与复选框的中心在基线上方 0.37em，序号与
  /// 正文基线相同；相邻两项相隔一个整行 + 4dp，不比项内换行更挤。
  Future<void> expectMarkersAligned(
    WidgetTester tester, {
    required double em,
    required double lineHeight,
  }) async {
    final checkbox = _markRect(tester, find.byType(DiaryTodoCheckbox).first);
    expect(checkbox.height, closeTo(18 * em / 16, 0.01));
    expect(
      checkbox.center.dy,
      closeTo(_firstBaseline(tester, 'task') - 0.37 * em, 0.5),
    );
    final bullet = _markRect(tester, _markerOf(DiaryBulletMarker, 'dot'));
    expect(
      bullet.center.dy,
      closeTo(_firstBaseline(tester, 'dot') - 0.37 * em, 0.5),
    );
    final number = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: _markerOf(DiaryNumberMarker, 'first'),
        matching: find.byType(RichText),
      ),
    );
    final label = TextPainter(
      text: number.text,
      textDirection: TextDirection.ltr,
      textScaler: number.textScaler,
      textHeightBehavior: number.textHeightBehavior,
    )..layout();
    expect(
      number.localToGlobal(Offset.zero).dy +
          label.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      closeTo(_firstBaseline(tester, 'first'), 0.5),
    );
    label.dispose();
    expect(
      _firstBaseline(tester, 'next') - _firstBaseline(tester, 'task'),
      closeTo(em * lineHeight + 4, 0.5),
    );
  }

  List<Map<String, Object?>> markerSample() => [
    _block('todo_list', 'task', data: {'checked': false}),
    _block('todo_list', 'next', data: {'checked': true}),
    _block('bulleted_list', 'dot'),
    _block('numbered_list', 'first'),
  ];

  testWidgets('markers line up with the first line of their text', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      _document(markerSample()),
    );
    await pump(tester, controller);
    await expectMarkersAligned(
      tester,
      em: appearance.typography.fontSize,
      lineHeight: appearance.typography.lineHeight,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('markers scale with large body text and system text scaling', (
    tester,
  ) async {
    const large = DiaryTextAppearance(
      typography: DiaryTypography(fontSize: 24, lineHeight: 2),
    );
    final controller = DiaryEditorController.fromContent(
      _document([
        ...markerSample(),
        _block(
          'bulleted_list',
          'parent',
          children: [_block('bulleted_list', 'child')],
        ),
      ]),
    );
    await pump(tester, controller, appearance: large, textScale: 1.3);
    await expectMarkersAligned(tester, em: 24 * 1.3, lineHeight: 2);
    // 子块缩进等于标记列宽：子项的标记格从上一级正文的起点开始。
    expect(
      tester.getTopLeft(_markerOf(DiaryBulletMarker, 'child')).dx,
      closeTo(_paragraph(tester, 'parent').localToGlobal(Offset.zero).dx, 0.5),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('heading sizes follow the body font size', (tester) async {
    const large = DiaryTextAppearance(
      typography: DiaryTypography(fontSize: 24),
    );
    final controller = DiaryEditorController.fromContent(
      _document([
        for (var level = 1; level <= 6; level++)
          _block('heading', 'h$level', data: {'level': level}),
      ]),
    );
    await pump(tester, controller, appearance: large);
    for (var level = 1; level <= 6; level++) {
      double? size;
      _paragraph(tester, 'h$level').text.visitChildren((span) {
        size ??= span.style?.fontSize;
        return size == null;
      });
      // 上游标题块自带的 32 / 28 / 24 / 18 默认字号不得覆盖正文字号的倍数。
      expect(
        size,
        closeTo(24 * kDiaryHeadingScales[level - 1], 0.01),
        reason: 'h$level',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
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
