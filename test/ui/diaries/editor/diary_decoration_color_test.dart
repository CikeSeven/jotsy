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
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_script_spans.dart';

import '../../../support/expressive_test_theme.dart';

/// 下划线与删除线的颜色跟随文字色：Material 3 的正文样式自带墨色的
/// decorationColor，不逐段写上的话线条一律是墨色。
void main() {
  const red = Color(0xFFE53935);
  const blue = Color(0xFF1E88E5);

  Map<String, Object?> block(
    String type,
    List<Map<String, Object?>> delta, {
    Map<String, Object?> data = const {},
  }) => {
    'type': type,
    'data': {'delta': delta, ...data},
  };

  Map<String, Object?> run(String text, [Map<String, Object?>? attributes]) => {
    'insert': text,
    if (attributes != null) 'attributes': attributes,
  };

  Future<DiaryEditorController> pump(
    WidgetTester tester,
    List<Map<String, Object?>> blocks, {
    required Brightness brightness,
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
          theme: expressiveTestTheme(brightness),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiaryEditor(
              controller: controller,
              // 首行缩进：段首的字画在占位里，同样要跟随文字色。
              appearance: const DiaryTextAppearance(
                typography: DiaryTypography(firstLineIndent: 2),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// 正文里文字恰为 [text] 的那一段的样式。
  TextStyle styleOf(WidgetTester tester, String text) {
    TextStyle? found;
    for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
      widget.text.visitChildren((span) {
        if (span is! TextSpan || span.text != text) return true;
        found = span.style;
        return false;
      });
      if (found != null) return found!;
    }
    throw StateError('no span "$text"');
  }

  for (final brightness in Brightness.values) {
    testWidgets('lines follow the text color in ${brightness.name}', (
      tester,
    ) async {
      final controller = await pump(tester, [
        block('paragraph', [
          run('红色', {'underline': true, 'font_color': '#FFE53935'}),
          run('墨色', {'underline': true}),
          run('蓝色', {'strikethrough': true, 'font_color': '#FF1E88E5'}),
        ]),
        block('paragraph', [
          run('甲'),
          run('x', {
            'underline': true,
            'script': 'super',
            'font_color': '#FFE53935',
          }),
        ]),
        block('quote', [
          run('引用', {'underline': true}),
        ]),
      ], brightness: brightness);
      final colors = Theme.of(
        tester.element(find.byType(DiaryEditor)),
      ).colorScheme;

      // 段首的字（首行缩进的占位里）与之后的文字。
      for (final (text, color) in [
        ('红', red),
        ('色', red),
        ('墨色', colors.onSurface),
        ('蓝色', blue),
      ]) {
        final style = styleOf(tester, text);
        expect(style.color, color, reason: text);
        expect(style.decorationColor, color, reason: text);
      }
      // 相邻两段线型相同、颜色不同：各自写上颜色，引擎才不会并成一条线。
      expect(
        styleOf(tester, '色').decorationColor,
        isNot(styleOf(tester, '墨色').decorationColor),
      );
      // 上标的字画在占位里。
      final script = tester.widget<DiaryScriptGlyph>(
        find.byType(DiaryScriptGlyph),
      );
      expect(script.style.decorationColor, red);
      // 引用的次要色是块样式，线条随它。
      final quote = styleOf(tester, '引用');
      expect(quote.color, colors.onSurfaceVariant);
      expect(quote.decorationColor, colors.onSurfaceVariant);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets('links and checked to-dos keep their own line color', (
    tester,
  ) async {
    final controller = await pump(tester, [
      block('paragraph', [
        run('看'),
        run('网址', {'href': 'https://example.com', 'underline': true}),
      ]),
      block(
        'todo_list',
        [
          run('完成', {'underline': true, 'font_color': '#FFE53935'}),
        ],
        data: {'checked': true},
      ),
    ], brightness: Brightness.light);
    final colors = Theme.of(
      tester.element(find.byType(DiaryEditor)),
    ).colorScheme;

    expect(
      styleOf(tester, '网址').decorationColor,
      colors.primary.withValues(alpha: 0.6),
    );
    final done = styleOf(tester, '完成');
    expect(done.decoration!.contains(TextDecoration.lineThrough), isTrue);
    expect(done.decorationColor, colors.onSurfaceVariant);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
