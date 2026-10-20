import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/controllers/diary_code_language_tracker.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_theme.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_quill_styles.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';

import '../../../support/expressive_test_theme.dart';

const _code = 'def greet(name):\n    return name';

/// 一个代码块，属性值为 [value]（true / 'plain' / 语言 id）。
quill.Document _codeDocument(Object value, {String text = _code}) {
  final ops = <Map<String, Object?>>[];
  for (final line in text.split('\n')) {
    ops
      ..add(<String, Object?>{'insert': line})
      ..add(<String, Object?>{
        'insert': '\n',
        'attributes': <String, Object?>{'code-block': value},
      });
  }
  return quill.Document.fromJson(ops);
}

quill.QuillController _controller(quill.Document document) =>
    quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );

/// 经 [DiaryQuillStylesBuilder] 渲染只读正文，返回解析出的外观。
Future<DiaryQuillLook> _pump(
  WidgetTester tester,
  quill.QuillController controller, {
  DiaryCodeBlockStyle style = DiaryCodeBlockStyle.defaults,
  Brightness brightness = Brightness.light,
}) async {
  late DiaryQuillLook captured;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(
          body: DiaryQuillStylesBuilder(
            appearance: const DiaryTextAppearance(
              typography: DiaryTypography(),
            ),
            controller: controller,
            codeBlockStyle: style,
            builder: (BuildContext context, DiaryQuillLook look) {
              captured = look;
              return quill.QuillEditor.basic(
                controller: controller,
                config: look.configure(
                  const quill.QuillEditorConfig(
                    autoFocus: false,
                    scrollable: false,
                    showCursor: false,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  return captured;
}

/// 正文里所有 RichText 的全部 TextSpan（含嵌套子 span）。
List<TextSpan> _renderedSpans(WidgetTester tester) {
  final spans = <TextSpan>[];
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((InlineSpan span) {
      if (span is TextSpan) {
        spans.add(span);
      }
      return true;
    });
  }
  return spans;
}

/// 某行 RichText 的根 span（行样式在它上面）。
TextSpan _lineRoot(WidgetTester tester, String lineText) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .map((rich) => rich.text)
      .whereType<TextSpan>()
      .firstWhere((span) => span.toPlainText() == lineText);
}

Color? _keyword(DiaryQuillLook look) =>
    look.code.palette.tokens[DiaryCodeTokenRole.keyword];

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('typing short code refreshes automatic highlighting in '
        '${brightness.name} mode', (tester) async {
      final controller = _controller(_codeDocument(true, text: 'd'))
        ..readOnly = false;
      final look = await _pump(tester, controller, brightness: brightness);
      var block = controller.document.root.children.first as quill.Block;
      expect(look.tracker.lastDetected(block), isNull);

      const python = 'def greet(name):';
      controller.replaceText(
        0,
        1,
        python,
        const TextSelection.collapsed(offset: python.length),
      );
      await tester.pump();
      expect(look.tracker.lastDetected(block), isNull);
      await tester.pump(DiaryCodeLanguageTracker.debounce);
      await tester.pump();
      expect(look.tracker.lastDetected(block), 'python');
      expect(
        _renderedSpans(
          tester,
        ).singleWhere((span) => span.text == 'def').style?.color,
        _keyword(look),
      );

      const typescript = 'const count: number = 42;';
      controller.replaceText(
        0,
        python.length,
        typescript,
        const TextSelection.collapsed(offset: typescript.length),
      );
      await tester.pump();
      block = controller.document.root.children.first as quill.Block;
      expect(look.tracker.lastDetected(block), 'python');
      await tester.pump(DiaryCodeLanguageTracker.debounce);
      await tester.pump();
      expect(look.tracker.lastDetected(block), 'typescript');
      expect(
        _renderedSpans(
          tester,
        ).singleWhere((span) => span.text == 'const').style?.color,
        _keyword(look),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets('a python block colors its keywords with the palette', (
    tester,
  ) async {
    final look = await _pump(tester, _controller(_codeDocument('python')));

    final def = _renderedSpans(tester).where((span) => span.text == 'def');
    expect(def, isNotEmpty);
    expect(def.first.style?.color, _keyword(look));
  });

  testWidgets('a string-valued block still gets the code font', (tester) async {
    await _pump(tester, _controller(_codeDocument('python')));

    final root = _lineRoot(tester, 'def greet(name):');
    expect(root.style?.fontFamily, 'monospace');
  });

  testWidgets('an unspecified block is plain when auto-detect is off', (
    tester,
  ) async {
    await _pump(
      tester,
      _controller(_codeDocument(true)),
      style: DiaryCodeBlockStyle.defaults.copyWith(autoDetect: false),
    );

    final texts = _renderedSpans(tester).map((span) => span.text);
    // 不高亮时整段叶子是一个 span，不会拆出 'def'。
    expect(texts, contains('def greet(name):'));
    expect(texts, isNot(contains('def')));
    expect(
      _lineRoot(tester, 'def greet(name):').style?.fontFamily,
      'monospace',
    );
  });

  testWidgets('an unspecified block is highlighted by the detected language', (
    tester,
  ) async {
    const python =
        'import os\n'
        '\n'
        'def greet(name, times=3):\n'
        '    """Say hello."""\n'
        '    for _ in range(times):\n'
        '        print(f"Hello, {name}!")\n'
        '    return None\n'
        '\n'
        'class Greeter(object):\n'
        '    def __init__(self):\n'
        '        self.count = 0';
    final controller = _controller(_codeDocument(true, text: python));
    final look = await _pump(tester, controller);

    final def = _renderedSpans(tester).where((span) => span.text == 'def');
    expect(def, isNotEmpty);
    expect(def.first.style?.color, _keyword(look));
    expect(
      look.tracker.lastDetected(
        controller.document.root.children.first as quill.Block,
      ),
      'python',
    );
  });

  testWidgets('a plain block is never highlighted', (tester) async {
    await _pump(tester, _controller(_codeDocument('plain')));

    final texts = _renderedSpans(tester).map((span) => span.text);
    expect(texts, contains('def greet(name):'));
    expect(texts, isNot(contains('def')));
  });

  testWidgets('line numbers use the palette color and can be turned off', (
    tester,
  ) async {
    final controller = _controller(_codeDocument('python'));
    final look = await _pump(tester, controller);

    final points = tester.widgetList<quill.QuillNumberPoint>(
      find.byType(quill.QuillNumberPoint),
    );
    expect(points, hasLength(2));
    for (final point in points) {
      expect(point.style.color, look.code.palette.lineNumber);
    }

    await _pump(
      tester,
      controller,
      style: DiaryCodeBlockStyle.defaults.copyWith(lineNumbers: false),
    );
    expect(find.byType(quill.QuillNumberPoint), findsNothing);
  });

  group('span builder called directly', () {
    late DiaryQuillLook look;
    late BuildContext context;
    late quill.TextSpanBuilder builder;

    Future<quill.Document> setUpDocument(
      WidgetTester tester,
      quill.Document document,
    ) async {
      look = await _pump(tester, _controller(document));
      context = tester.element(find.byType(quill.QuillEditor));
      builder = look.configure(const quill.QuillEditorConfig()).textSpanBuilder;
      return document;
    }

    quill.QuillText firstLeaf(quill.Document document, {int line = 0}) {
      final block = document.root.children.first as quill.Block;
      final target = block.children.elementAt(line) as quill.Line;
      return target.children.first as quill.QuillText;
    }

    List<TextSpan> children(InlineSpan span) =>
        ((span as TextSpan).children ?? const <InlineSpan>[])
            .cast<TextSpan>()
            .toList();

    testWidgets('composing slices map to offsets inside the block', (
      tester,
    ) async {
      final document = await setUpDocument(tester, _codeDocument('python'));
      final leaf = firstLeaf(document);
      const style = TextStyle(decoration: TextDecoration.underline);

      // 组字中的切片：叶子内第 1 个字符起的 'ef g'。
      final span = builder(context, leaf, 1, 'ef g', style, null);
      expect(span.toPlainText(), 'ef g');
      expect((span as TextSpan).style, style);
      final parts = children(span);
      expect(parts.first.text, 'ef');
      expect(parts.first.style?.color, _keyword(look));

      // 第二行的切片同样按块内偏移取色：'return' 是关键字。
      final second = firstLeaf(document, line: 1);
      final returnSpan = builder(context, second, 4, 'return', null, null);
      expect(children(returnSpan).single.text, 'return');
      expect(children(returnSpan).single.style?.color, _keyword(look));
    });

    testWidgets('a leaf with its own color keeps it', (tester) async {
      final document = await setUpDocument(
        tester,
        quill.Document.fromJson(<Map<String, Object?>>[
          <String, Object?>{
            'insert': 'def',
            'attributes': <String, Object?>{'color': '#FFFF0000'},
          },
          <String, Object?>{'insert': ' greet():'},
          <String, Object?>{
            'insert': '\n',
            'attributes': <String, Object?>{'code-block': 'python'},
          },
        ]),
      );
      final leaf = firstLeaf(document);
      const style = TextStyle(color: Color(0xFFFF0000));

      final span = builder(context, leaf, 0, 'def', style, null);
      final parts = children(span);
      expect(parts.single.text, 'def');
      expect(parts.single.style?.color, isNull);
      expect((span as TextSpan).style?.color, const Color(0xFFFF0000));
    });

    testWidgets('a detached (cloned) leaf falls back to the default span', (
      tester,
    ) async {
      await setUpDocument(tester, _codeDocument('python'));

      final span = builder(
        context,
        quill.QuillText('def x'),
        0,
        'def x',
        null,
        null,
      );
      expect((span as TextSpan).text, 'def x');
      expect(span.children, isNull);
    });
  });
}
