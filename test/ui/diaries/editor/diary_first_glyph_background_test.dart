import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';

import '../../../support/expressive_test_theme.dart';

/// 首行缩进时段首的字画在占位里：它的背景色（高亮）必须与同一行其他字的
/// 背景一样高，不能因为单独排版而上下各多出半个行距。
void main() {
  // 行距放大到 2 倍：半个行距 = 半个字号，差异一眼可见。
  const appearance = DiaryTextAppearance(
    typography: DiaryTypography(firstLineIndent: 2, lineHeight: 2),
  );

  Map<String, Object?> paragraph(List<Map<String, Object?>> delta) => {
    'type': 'paragraph',
    'data': {'delta': delta},
  };

  Map<String, Object?> highlighted(String text) => {
    'insert': text,
    'attributes': {'bg_color': '#FFFF0000'},
  };

  Map<String, Object?> plain(String text) => {'insert': text};

  final boundaryKey = GlobalKey();

  Future<DiaryEditorController> pump(
    WidgetTester tester,
    List<Map<String, Object?>> blocks, {
    double textScale = 1,
  }) async {
    final controller = DiaryEditorController.fromContent(
      jsonEncode({
        'document': {'type': 'page', 'children': blocks},
      }),
    );
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
          home: RepaintBoundary(
            key: boundaryKey,
            child: Scaffold(
              body: DiaryEditor(controller: controller, appearance: appearance),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> tearDownEditor(
    WidgetTester tester,
    DiaryEditorController controller,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  }

  /// 整页截图（逻辑像素 = 物理像素）。
  Future<_Shot> capture(WidgetTester tester) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final data = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final shot = _Shot(image.width, image.height, data);
    image.dispose();
    return shot;
  }

  /// 段首占位里画出来的第 [index] 个（文档顺序）段首字。
  Rect firstGlyphRect(WidgetTester tester, String glyph, {int index = 0}) =>
      tester.getRect(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is RichText && widget.text.toPlainText() == glyph,
            )
            .at(index),
      );

  /// 段首字与紧挨着的第二个字（Ahem 字宽 = 字号，正方形）各自那一列里，
  /// 包含字中心的着色区段（高亮或字形）。
  (_Run, _Run) firstTwoColumns(_Shot shot, Rect glyph) {
    final second = glyph.right + glyph.width / 2;
    return (
      shot.inkRun(glyph.center.dx.round(), glyph.center.dy.round()),
      shot.inkRun(second.round(), glyph.center.dy.round()),
    );
  }

  testWidgets('the indented first character highlights as tall as the rest '
      'of the first line of a multi-line paragraph', (tester) async {
    final controller = await pump(tester, [
      paragraph([highlighted('ABCD EFGH'), plain(' IJKL' * 30)]),
    ]);
    final shot = await capture(tester);
    final glyph = firstGlyphRect(tester, 'A');
    final (first, second) = firstTwoColumns(shot, glyph);
    // Ahem 的字形是实心方块，盖住字框里的背景；字框下方露出的是高亮色。
    expect(shot.isHighlight(second.x, second.bottom), isTrue);
    expect(first, second);
    // 背景比字框高：下沿带着下方半个行距（16 × (2 − 1) / 2 = 8）。
    expect(first.bottom - glyph.bottom.round(), closeTo(8, 1));
    expect(first.top, glyph.top.round());
    await tearDownEditor(tester, controller);
  });

  testWidgets('a single-line paragraph highlights its indented first '
      'character as tall as the characters beside it', (tester) async {
    final controller = await pump(tester, [
      paragraph([highlighted('ABCD'), plain(' EF')]),
    ]);
    final shot = await capture(tester);
    final glyph = firstGlyphRect(tester, 'A');
    final (first, second) = firstTwoColumns(shot, glyph);
    expect(first, second);
    // 只有一行：首行上方与末行下方都不加行距，背景即字框。
    expect(first.top, glyph.top.round());
    expect(first.bottom, glyph.bottom.round() - 1);
    await tearDownEditor(tester, controller);
  });

  testWidgets('a soft line break at the end keeps the first line spaced '
      'below like its other characters', (tester) async {
    final controller = await pump(tester, [
      paragraph([highlighted('ABCD'), plain('\n')]),
    ]);
    final shot = await capture(tester);
    final (first, second) = firstTwoColumns(shot, firstGlyphRect(tester, 'A'));
    expect(first, second);
    await tearDownEditor(tester, controller);
  });

  testWidgets('the highlight matches its line under a larger text scale', (
    tester,
  ) async {
    final controller = await pump(tester, [
      paragraph([highlighted('ABCD EFGH'), plain(' IJKL' * 30)]),
      paragraph([highlighted('ABCD'), plain(' EF')]),
    ], textScale: 1.5);
    final shot = await capture(tester);
    for (final index in [0, 1]) {
      final (first, second) = firstTwoColumns(
        shot,
        firstGlyphRect(tester, 'A', index: index),
      );
      expect(first, second, reason: 'paragraph $index');
    }
    await tearDownEditor(tester, controller);
  });

  testWidgets('the indent before a highlighted first character stays '
      'unpainted', (tester) async {
    final controller = await pump(tester, [
      paragraph([highlighted('ABCD EFGH'), plain(' IJKL' * 30)]),
    ]);
    final shot = await capture(tester);
    final glyph = firstGlyphRect(tester, 'A');
    // 缩进两字 = 32px，取缩进中间那一列。
    final x = (glyph.left - 16).round();
    for (var y = shot.clampY(glyph.top - 8); y < glyph.bottom + 8; y++) {
      expect(shot.isHighlight(x, y), isFalse, reason: 'y = $y');
    }
    await tearDownEditor(tester, controller);
  });

  testWidgets('a first character without a background paints none', (
    tester,
  ) async {
    final controller = await pump(tester, [
      paragraph([plain('AB'), highlighted('CD'), plain(' IJKL' * 30)]),
    ]);
    final shot = await capture(tester);
    final glyph = firstGlyphRect(tester, 'A');
    for (var y = shot.clampY(glyph.top - 8); y < glyph.bottom + 8; y++) {
      expect(
        shot.isHighlight(glyph.center.dx.round(), y),
        isFalse,
        reason: 'y = $y',
      );
    }
    await tearDownEditor(tester, controller);
  });
}

/// 一列里连续着色（与页面底色不同）的区段，[x] 为所在列。
@immutable
class _Run {
  const _Run(this.x, this.top, this.bottom);

  final int x;
  final int top;
  final int bottom;

  @override
  bool operator ==(Object other) =>
      other is _Run && other.top == top && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(top, bottom);

  @override
  String toString() => '_Run(x: $x, $top–$bottom)';
}

class _Shot {
  _Shot(this.width, this.height, this.data);

  final int width;
  final int height;
  final ByteData data;

  int _pixel(int x, int y) => data.getUint32((y * width + x) * 4);

  /// 页面底色：取左下角（编辑区下方的空白）。
  late final int _page = _pixel(1, height - 2);

  int clampY(double y) => y.round().clamp(0, height - 1);

  bool isHighlight(int x, int y) {
    final i = (y * width + x) * 4;
    return data.getUint8(i) > 200 &&
        data.getUint8(i + 1) < 60 &&
        data.getUint8(i + 2) < 60;
  }

  /// 第 [x] 列里包含 ([x], [y]) 的连续着色区段。
  _Run inkRun(int x, int y) {
    var top = y;
    while (top > 0 && _pixel(x, top - 1) != _page) {
      top--;
    }
    var bottom = y;
    while (bottom < height - 1 && _pixel(x, bottom + 1) != _page) {
      bottom++;
    }
    return _Run(x, top, bottom);
  }
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
