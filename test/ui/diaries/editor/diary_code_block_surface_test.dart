import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_fonts.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_code_block_surface.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_code_line_numbers.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor_styles.dart';

Future<DiaryEditorController> _pumpCodeBlock(
  WidgetTester tester,
  String code, {
  String? language,
  bool readOnly = true,
  bool shrinkWrap = true,
  DiaryCodeBlockStyle codeBlockStyle = DiaryCodeBlockStyle.defaults,
  DiaryTypography typography = const DiaryTypography(
    fontSize: 16,
    lineHeight: 1.6,
  ),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size viewport = const Size(360, 800),
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final doc = af.Document(
    root: af.pageNode(
      children: [
        af.Node(
          type: 'code',
          attributes: {
            'delta': (af.Delta()..insert(code)).toJson(),
            'language': ?language,
          },
        ),
      ],
    ),
  );
  final controller = DiaryEditorController(document: doc, readOnly: readOnly);
  final appearance = DiaryTextAppearance(typography: typography);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildSeededAppTheme(Colors.blue, brightness),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: shrinkWrap
              ? SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: DiaryEditor(
                      controller: controller,
                      appearance: appearance,
                      shrinkWrap: true,
                      codeBlockStyle: codeBlockStyle,
                    ),
                  ),
                )
              : DiaryEditor(
                  controller: controller,
                  appearance: appearance,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  codeBlockStyle: codeBlockStyle,
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// 找出代码块内部实际渲染代码正文的 RenderParagraph（AppFlowyRichText 的第二个）。
RenderParagraph _codeParagraph(WidgetTester tester) {
  final richTexts = tester
      .renderObjectList<RenderParagraph>(
        find.descendant(
          of: find.byType(af.AppFlowyRichText),
          matching: find.byType(RichText),
        ),
      )
      .toList();
  expect(richTexts.length, greaterThanOrEqualTo(2));
  return richTexts.last;
}

/// 构建贴近 #381 的 725 行脚本：含空行、长折行、中文注释与末尾两行。
String _longPythonScript({int lines = 725}) {
  final buffer = StringBuffer();
  for (var i = 1; i <= lines; i++) {
    if (i > 1) buffer.write('\n');
    if (i == lines - 1) {
      buffer.write('PYEOF');
    } else if (i == lines) {
      buffer.write('python3 pcm_align_check.py');
    } else if (i % 15 == 0) {
      buffer.write('');
    } else if (i % 11 == 0) {
      buffer.write('    # 检查音频对齐与编码转换：支持 WAV / FLAC / PCM $i');
    } else if (i % 7 == 0) {
      buffer.write(
        '        return raw.decode(encoding), encoding  # fallback line $i',
      );
    } else if (i % 5 == 0) {
      buffer.write('    with open(path, "rb") as f: raw = f.read()');
    } else {
      buffer.write('    line_$i = value_$i + 1');
    }
  }
  return buffer.toString();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader(kAppBundledFontFamily)
      ..addFont(
        rootBundle.load(
          'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_Regular.ttf',
        ),
      );
    await loader.load();
  });

  test(
    'diaryCodeLineStarts splits logical lines including empty and trailing',
    () {
      expect(diaryCodeLineStarts(''), [0]);
      expect(diaryCodeLineStarts('single line'), [0]);
      expect(diaryCodeLineStarts('a\nb\nc'), [0, 2, 4]);
      expect(diaryCodeLineStarts('a\n'), [0, 2]);
      expect(diaryCodeLineStarts('\n\n'), [0, 1, 2]);
      expect(diaryCodeLineStarts('a\n\nb'), [0, 2, 3]);
    },
  );

  test(
    'gutter keeps 32dp for two-digit line counts and widens for 3-5 digits',
    () {
      const style = TextStyle(fontSize: 14.4, height: 1.5);
      final twoDigits = diaryCodeGutterMetrics(
        lineCount: 99,
        style: style,
        scaler: TextScaler.noScaling,
      );
      expect(
        twoDigits.numberRight,
        greaterThanOrEqualTo(kDiaryCodeMinLineNumberWidth),
      );
      expect(twoDigits.width, twoDigits.numberRight + kDiaryCodeLineNumberGap);

      final threeDigits = diaryCodeGutterMetrics(
        lineCount: 725,
        style: style,
        scaler: TextScaler.noScaling,
      );
      final fourDigits = diaryCodeGutterMetrics(
        lineCount: 1200,
        style: style,
        scaler: TextScaler.noScaling,
      );
      final scaled = diaryCodeGutterMetrics(
        lineCount: 725,
        style: style,
        scaler: const TextScaler.linear(1.3),
      );
      expect(threeDigits.width, greaterThan(twoDigits.width));
      expect(fourDigits.width, greaterThan(threeDigits.width));
      expect(scaled.width, greaterThan(threeDigits.width));

      // 任意最大行号右对齐后左缘 >= 0，不会向左溢出槽外。
      for (final (count, metrics, scaler) in [
        (99, twoDigits, TextScaler.noScaling),
        (725, threeDigits, TextScaler.noScaling),
        (1200, fourDigits, TextScaler.noScaling),
        (725, scaled, const TextScaler.linear(1.3)),
      ]) {
        final painter = TextPainter(
          text: TextSpan(text: '$count', style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        expect(metrics.numberRight - painter.width, greaterThanOrEqualTo(0));
        painter.dispose();
      }

      // 极窄容器夹取后仍留出正文最小宽度且数值非负。
      final clamped = clampDiaryCodeGutterMetrics(fourDigits, 40);
      expect(clamped.width, lessThanOrEqualTo(40 - kDiaryCodeMinContentWidth));
      expect(clamped.numberRight, greaterThanOrEqualTo(0));
    },
  );

  testWidgets(
    'node.key aligns with layerLink target so shifted selection rects and carets match global text geometry',
    (tester) async {
      final code = _longPythonScript(lines: 120);
      for (final (label, style, brightness) in [
        (
          'header+lineNumbers light',
          DiaryCodeBlockStyle.defaults,
          Brightness.light,
        ),
        (
          'header+lineNumbers dark',
          DiaryCodeBlockStyle.defaults,
          Brightness.dark,
        ),
        (
          'no header',
          DiaryCodeBlockStyle.defaults.copyWith(header: false),
          Brightness.light,
        ),
        (
          'no lineNumbers',
          DiaryCodeBlockStyle.defaults.copyWith(lineNumbers: false),
          Brightness.light,
        ),
        (
          'plain border',
          DiaryCodeBlockStyle.defaults.copyWith(
            header: false,
            lineNumbers: false,
            border: true,
          ),
          Brightness.dark,
        ),
      ]) {
        final controller = await _pumpCodeBlock(
          tester,
          code,
          language: 'python',
          codeBlockStyle: style,
          brightness: brightness,
        );
        final node = controller.document.root.children.first;
        final nodeBox =
            node.key.currentContext!.findRenderObject()! as RenderBox;
        final surfaceBox = tester.renderObject<RenderBox>(
          find.byType(DiaryCodeBlockSurface),
        );
        final targetBox = tester.renderObject<RenderBox>(
          find.ancestor(
            of: find.byType(DiaryCodeBlockSurface),
            matching: find.byWidgetPredicate(
              (w) => w is CompositedTransformTarget && w.link == node.layerLink,
            ),
          ),
        );

        // node.key 必须与 CompositedTransformTarget（node.layerLink）完全重合。
        expect(
          nodeBox.localToGlobal(Offset.zero),
          targetBox.localToGlobal(Offset.zero),
          reason: label,
        );
        expect(nodeBox.size, surfaceBox.size, reason: label);

        final startOffset = code.indexOf('line_97');
        final endOffset = code.indexOf('line_101') + 8;
        final selection = af.Selection.single(
          path: node.path,
          startOffset: startOffset,
          endOffset: endOffset,
        );
        controller.state.selection = selection;
        await tester.pumpAndSettle();

        final selectable = node.selectable!;
        final shiftedRects = selectable.getRectsInSelection(
          selection,
          shiftWithBaseOffset: true,
        );
        final unshiftedRects = selectable.getRectsInSelection(
          selection,
          shiftWithBaseOffset: false,
        );
        expect(shiftedRects, isNotEmpty, reason: label);

        // baseOffset 必须把选区框平移到相对 layerLink 的正确位置，与全局真实坐标一致。
        final targetOrigin = targetBox.localToGlobal(Offset.zero);
        final firstFromLayerLink = shiftedRects.first.shift(targetOrigin);
        final firstFromParagraph = selectable.transformRectToGlobal(
          unshiftedRects.first,
        );
        final lastFromLayerLink = shiftedRects.last.shift(targetOrigin);
        final lastFromParagraph = selectable.transformRectToGlobal(
          unshiftedRects.last,
        );
        final editorRects = controller.state.selectionRects();
        expect(
          firstFromLayerLink.left,
          closeTo(firstFromParagraph.left, 0.01),
          reason: label,
        );
        expect(
          firstFromLayerLink.top,
          closeTo(firstFromParagraph.top, 0.01),
          reason: label,
        );
        expect(
          lastFromLayerLink.right,
          closeTo(lastFromParagraph.right, 0.01),
          reason: label,
        );
        expect(
          lastFromLayerLink.bottom,
          closeTo(lastFromParagraph.bottom, 0.01),
          reason: label,
        );
        expect(
          editorRects.first.topLeft.dx,
          closeTo(firstFromParagraph.left, 0.01),
          reason: label,
        );
        expect(
          editorRects.first.topLeft.dy,
          closeTo(firstFromParagraph.top, 0.01),
          reason: label,
        );

        // 折叠光标矩形（MobileCollapsedHandle）同样精确对齐。
        final caretPos = af.Position(path: node.path, offset: startOffset);
        final shiftedCaret = selectable.getCursorRectInPosition(
          caretPos,
          shiftWithBaseOffset: true,
        )!;
        final globalCaret = selectable.transformRectToGlobal(
          selectable.getCursorRectInPosition(caretPos)!,
        );
        expect(
          shiftedCaret.shift(targetOrigin).topLeft.dx,
          closeTo(globalCaret.left, 0.01),
          reason: label,
        );
        expect(
          shiftedCaret.shift(targetOrigin).topLeft.dy,
          closeTo(globalCaret.top, 0.01),
          reason: label,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    '725-line code block line numbers match RenderParagraph layout without bottom overflow across fonts and scales',
    (tester) async {
      final code = _longPythonScript(lines: 725);
      final lineStarts = diaryCodeLineStarts(code);
      expect(lineStarts, hasLength(725));

      for (final (label, style, scale) in [
        ('mono default', DiaryCodeBlockStyle.defaults, 1.0),
        (
          'body font',
          DiaryCodeBlockStyle.defaults.copyWith(fontId: kDiaryCodeFontBody),
          1.0,
        ),
        ('mono scaled 1.25', DiaryCodeBlockStyle.defaults, 1.25),
      ]) {
        final controller = await _pumpCodeBlock(
          tester,
          code,
          codeBlockStyle: style,
          textScale: scale,
        );
        final paragraph = _codeParagraph(tester);
        final allEntries = diaryCodeVisibleLineNumbers(
          paragraph: paragraph,
          lineStarts: lineStarts,
          textLength: code.length,
          clipTop: 0,
          clipBottom: paragraph.size.height,
          lineMargin: 48,
        );
        expect(allEntries, hasLength(725), reason: label);
        expect(allEntries.first.lineNumber, 1, reason: label);
        expect(allEntries.first.top, 0.0, reason: label);
        expect(
          allEntries.first.behavior,
          kDiaryTextHeightBehavior,
          reason: label,
        );
        expect(allEntries.last.lineNumber, 725, reason: label);
        // 最后一行行号必须严格位于代码正文高度之内，绝不溢出底部（#381）。
        expect(
          allEntries.last.top,
          lessThan(paragraph.size.height),
          reason: label,
        );
        expect(
          allEntries.last.top,
          closeTo(
            paragraph
                .getOffsetForCaret(
                  TextPosition(offset: lineStarts.last),
                  Rect.zero,
                )
                .dy,
            0.01,
          ),
          reason: label,
        );

        // 二分可视窗口裁切：只返回窗口附近的几十行，不遍历整份 725 行。
        final midY = allEntries[100].top;
        final window = diaryCodeVisibleLineNumbers(
          paragraph: paragraph,
          lineStarts: lineStarts,
          textLength: code.length,
          clipTop: midY,
          clipBottom: midY + 400,
          lineMargin: 48,
        );
        expect(window.length, lessThan(60), reason: label);
        expect(window.any((e) => e.lineNumber == 101), isTrue, reason: label);
        expect(window.first.lineNumber, greaterThan(50), reason: label);
        expect(window.last.lineNumber, lessThan(200), reason: label);

        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }

      // ≤ 600 行开启语法高亮（含斜体注释）时行号同样与正文逐行对齐。
      final highlightedCode = _longPythonScript(lines: 120);
      final highlightedStarts = diaryCodeLineStarts(highlightedCode);
      final highlightedController = await _pumpCodeBlock(
        tester,
        highlightedCode,
        language: 'python',
      );
      final highlightedParagraph = _codeParagraph(tester);
      final highlightedEntries = diaryCodeVisibleLineNumbers(
        paragraph: highlightedParagraph,
        lineStarts: highlightedStarts,
        textLength: highlightedCode.length,
        clipTop: 0,
        clipBottom: highlightedParagraph.size.height,
        lineMargin: 48,
      );
      expect(highlightedEntries, hasLength(120));
      expect(
        highlightedEntries.last.top,
        lessThan(highlightedParagraph.size.height),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      highlightedController.dispose();
    },
  );

  testWidgets(
    'handles empty block, trailing newlines, narrow containers, and live line insertion',
    (tester) async {
      // 空代码块、末尾换行、仅换行符与极窄容器都不抛异常。
      for (final (code, viewport) in [
        ('', const Size(360, 800)),
        ('first\nsecond\n', const Size(360, 800)),
        ('\n\n\n', const Size(360, 800)),
        (
          'long_identifier_without_breaks = 1234567890\nline2',
          const Size(120, 400),
        ),
      ]) {
        final controller = await _pumpCodeBlock(
          tester,
          code,
          viewport: viewport,
        );
        final paragraph = _codeParagraph(tester);
        final starts = diaryCodeLineStarts(code);
        final entries = diaryCodeVisibleLineNumbers(
          paragraph: paragraph,
          lineStarts: starts,
          textLength: code.length,
          clipTop: 0,
          clipBottom: paragraph.size.height + 100,
          lineMargin: 48,
        );
        expect(entries, hasLength(starts.length));
        if (code.endsWith('\n')) {
          expect(entries.last.behavior, kDiaryTextHeightBehavior);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }

      // 编辑态从 99 行增到 100 行：行号槽动态加宽，且 selection baseOffset 随之更新。
      final lines99 = List.generate(99, (i) => 'x$i').join('\n');
      final controller = await _pumpCodeBlock(
        tester,
        lines99,
        readOnly: false,
        shrinkWrap: false,
      );
      final node = controller.document.root.children.first;
      final beforeX = _codeParagraph(tester).localToGlobal(Offset.zero).dx;
      final tx = controller.state.transaction
        ..insertText(node, lines99.length, '\nx99');
      controller.apply(tx);
      await tester.pumpAndSettle();
      final afterX = _codeParagraph(tester).localToGlobal(Offset.zero).dx;
      expect(afterX, greaterThan(beforeX));

      final pos = af.Position(path: node.path, offset: lines99.length + 1);
      final targetOrigin = tester
          .renderObject<RenderBox>(find.byType(DiaryCodeBlockSurface))
          .localToGlobal(Offset.zero);
      final shifted = node.selectable!
          .getCursorRectInPosition(pos, shiftWithBaseOffset: true)!
          .shift(targetOrigin);
      final global = node.selectable!.transformRectToGlobal(
        node.selectable!.getCursorRectInPosition(pos)!,
      );
      expect(shifted.left, closeTo(global.left, 0.01));
      expect(shifted.top, closeTo(global.top, 0.01));

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
