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
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_find_highlight.dart';

import '../../../support/expressive_test_theme.dart';

/// 查找高亮改的是匹配那几个字的文字样式（与搜索结果卡片同一种标法）：
/// 片段按匹配切开、文字与码元不变；跨行内格式（加粗、链接、行内代码）的
/// 匹配逐段标出，链接色同样被高亮盖过；相邻的非当前匹配合成一段；当前
/// 那一处换成更深的样式；字色归块管的引用与代码块改衬半透明主色；关掉
/// 查找后恢复原样。
void main() {
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
    bool readOnly = true,
  }) async {
    final controller = DiaryEditorController.fromContent(
      jsonEncode({
        'document': {'type': 'page', 'children': blocks},
      }),
      readOnly: readOnly,
    );
    addTearDown(controller.dispose);
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
          home: Scaffold(
            body: DiaryEditor(
              controller: controller,
              appearance: const DiaryTextAppearance(
                typography: DiaryTypography(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// 文字恰为 [plain] 的那个文字块的整段片段。
  InlineSpan spanOf(WidgetTester tester, String plain) {
    for (final element
        in find
            .descendant(
              of: find.byType(DiaryEditor),
              matching: find.byType(RichText),
            )
            .evaluate()) {
      final text = (element.widget as RichText).text;
      if (text.toPlainText(includePlaceholders: false) == plain) return text;
    }
    throw StateError('no rich text for "$plain"');
  }

  /// [span] 里自带文字、底色为 [background] 的片段。
  List<String> withBackground(InlineSpan span, Color? background) {
    final out = <String>[];
    span.visitChildren((child) {
      if (child is TextSpan &&
          child.text != null &&
          child.style?.backgroundColor == background) {
        out.add(child.text!);
      }
      return true;
    });
    return out;
  }

  DiaryFindHighlightStyles stylesOf(WidgetTester tester) =>
      DiaryFindHighlightStyles.of(
        Theme.of(tester.element(find.byType(DiaryEditor))).colorScheme,
      );

  testWidgets('matches across formats keep the text and take the style', (
    tester,
  ) async {
    const plain = 'see the link and code now';
    final controller = await pump(tester, [
      block('paragraph', [
        run('see '),
        run('the', {'bold': true}),
        run(' '),
        run('link', {'href': 'https://example.com'}),
        run(' and '),
        run('code', {'code': true}),
        run(' now'),
      ]),
    ]);
    final styles = stylesOf(tester);
    controller.find.open(text: 'link and code');
    await tester.pumpAndSettle();

    final span = spanOf(tester, plain);
    // 文字与码元不变（光标、选区的偏移照旧对应文档）。
    expect(span.toPlainText(), plain);
    // 当前那一处跨三个行内片段：逐段标出，链接色与行内代码的底色都被盖过。
    expect(withBackground(span, styles.current.backgroundColor), [
      'link',
      ' and ',
      'code',
    ]);
    span.visitChildren((child) {
      if (child is TextSpan &&
          child.text != null &&
          child.style?.backgroundColor == styles.current.backgroundColor) {
        expect(child.style?.color, styles.current.color);
        expect(child.style?.fontWeight, FontWeight.w600);
      }
      return true;
    });

    // 加粗的匹配保持原来更粗的字重。
    controller.find.setOptions(regex: true);
    controller.find.setText('the');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final bold = spanOf(tester, plain);
    final weights = <FontWeight?>[];
    bold.visitChildren((child) {
      if (child is TextSpan && child.text == 'the') {
        weights.add(child.style?.fontWeight);
      }
      return true;
    });
    expect(weights, [FontWeight.w700]);

    // 关掉查找：没有任何片段带高亮底色。
    controller.find.close();
    await tester.pumpAndSettle();
    final closed = spanOf(tester, plain);
    expect(withBackground(closed, styles.current.backgroundColor), isEmpty);
    expect(withBackground(closed, styles.match.backgroundColor), isEmpty);
  });

  testWidgets('adjacent matches merge and the current one is marked apart', (
    tester,
  ) async {
    final controller = await pump(tester, [
      block('paragraph', [run('aaaa b aa')]),
    ]);
    final styles = stylesOf(tester);
    controller.find.open(text: 'a');
    await tester.pumpAndSettle();
    final span = spanOf(tester, 'aaaa b aa');
    // 第一处是当前；其后紧挨着的三处合成一段，后面两处同样合成一段。
    expect(withBackground(span, styles.current.backgroundColor), ['a']);
    expect(withBackground(span, styles.match.backgroundColor), ['aaa', 'aa']);

    controller.find.next();
    await tester.pumpAndSettle();
    final moved = spanOf(tester, 'aaaa b aa');
    expect(withBackground(moved, styles.current.backgroundColor), ['a']);
    expect(withBackground(moved, styles.match.backgroundColor), [
      'a',
      'aa',
      'aa',
    ]);
  });

  testWidgets('blocks that own their ink get a tint and keep their color', (
    tester,
  ) async {
    final controller = await pump(tester, [
      block('code', [run('final value = 42;')], data: {'language': 'dart'}),
      block('quote', [run('a quoted value')]),
      block('paragraph', [run('plain value')]),
    ]);
    final styles = stylesOf(tester);
    controller.find.open(text: 'value');
    await tester.pumpAndSettle();

    // 代码块（当前那一处）与引用：半透明主色衬底，字色仍是块自己的。
    final code = spanOf(tester, 'final value = 42;');
    expect(withBackground(code, styles.currentTint.backgroundColor), ['value']);
    expect(withBackground(code, styles.current.backgroundColor), isEmpty);
    final quote = spanOf(tester, 'a quoted value');
    expect(withBackground(quote, styles.matchTint.backgroundColor), ['value']);
    final quoteInk = <Color?>{};
    quote.visitChildren((child) {
      if (child is TextSpan && child.text != null) {
        quoteInk.add(child.style?.color);
      }
      return true;
    });
    expect(quoteInk, hasLength(1));
    // 普通段落照常是搜索页的样式。
    final plain = spanOf(tester, 'plain value');
    expect(withBackground(plain, styles.match.backgroundColor), ['value']);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
