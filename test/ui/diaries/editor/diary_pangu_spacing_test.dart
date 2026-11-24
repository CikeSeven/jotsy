import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_fonts.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_text_style_options.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_resolved_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_pangu_text.dart';
import 'package:node_diary/utils/pangu_spacing.dart';

import '../../../support/expressive_test_theme.dart';

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}

/// 收集 [span] 里所有叶子文字片段及其有效 `letterSpacing`。
List<({String text, double? letterSpacing, double? fontSize})> _leafRuns(
  InlineSpan span, {
  TextStyle? inherited,
}) {
  final out = <({String text, double? letterSpacing, double? fontSize})>[];
  void visit(InlineSpan node, TextStyle? parent) {
    final merged = parent == null ? node.style : parent.merge(node.style);
    if (node is TextSpan) {
      if (node.text != null && node.text!.isNotEmpty) {
        out.add((
          text: node.text!,
          letterSpacing: merged?.letterSpacing,
          fontSize: merged?.fontSize,
        ));
      }
      final children = node.children;
      if (children != null) {
        for (final child in children) {
          visit(child, merged);
        }
      }
    }
  }

  visit(span, inherited);
  return out;
}

void main() {
  Map<String, Object?> block(
    String type,
    List<Map<String, Object?>> delta, {
    Map<String, Object?> data = const <String, Object?>{},
  }) => <String, Object?>{
    'type': type,
    'data': <String, Object?>{'delta': delta, ...data},
  };

  Map<String, Object?> run(String text, [Map<String, Object?>? attributes]) =>
      <String, Object?>{
        'insert': text,
        if (attributes != null) 'attributes': attributes,
      };

  Future<DiaryEditorController> pumpEditor(
    WidgetTester tester,
    List<Map<String, Object?>> blocks, {
    DiaryTypography typography = const DiaryTypography(panguSpacing: true),
    bool readOnly = true,
  }) async {
    final controller = DiaryEditorController.fromContent(
      jsonEncode(<String, Object?>{
        'document': <String, Object?>{'type': 'page', 'children': blocks},
      }),
      readOnly: readOnly,
    );
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(420, 900);
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
              appearance: DiaryTextAppearance(typography: typography),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  InlineSpan spanOf(WidgetTester tester, String plain) {
    for (final element
        in find
            .descendant(
              of: find.byType(DiaryEditor),
              matching: find.byType(RichText),
            )
            .evaluate()) {
      final span = (element.widget as RichText).text;
      if (span.toPlainText(includeSemanticsLabels: false) == plain) {
        return span;
      }
    }
    fail('No RichText with plain text "$plain" found.');
  }

  group('DiaryEditor pangu spacing', () {
    testWidgets('does not alter letterSpacing when disabled', (tester) async {
      await pumpEditor(tester, <Map<String, Object?>>[
        block('paragraph', <Map<String, Object?>>[run('用Flutter写3行')]),
      ], typography: const DiaryTypography(panguSpacing: false));

      final leaves = _leafRuns(spanOf(tester, '用Flutter写3行'));
      expect(leaves.map((r) => r.text).join(), '用Flutter写3行');
      expect(leaves.every((r) => (r.letterSpacing ?? 0) == 0), isTrue);
    });

    testWidgets(
      'adds proportional letterSpacing at CJK-Western boundaries without '
      'changing code units, including across styled runs and headings',
      (tester) async {
        const fontSize = 16.0;
        const baseTracking = 0.5;
        await pumpEditor(
          tester,
          <Map<String, Object?>>[
            block('paragraph', <Map<String, Object?>>[
              run('用'),
              run('Flutter', <String, Object?>{'bold': true}),
              run('写3行'),
            ]),
            block(
              'heading',
              <Map<String, Object?>>[run('第1章Intro')],
              data: <String, Object?>{'level': 1},
            ),
          ],
          typography: const DiaryTypography(
            fontSize: fontSize,
            letterSpacing: baseTracking,
            panguSpacing: true,
          ),
        );

        final bodySpan = spanOf(tester, '用Flutter写3行');
        expect(
          bodySpan.toPlainText(includeSemanticsLabels: false).length,
          '用Flutter写3行'.length,
        );
        final bodyLeaves = _leafRuns(bodySpan);
        final widened = baseTracking + panguSpacingExtent(fontSize);
        // 跨 run 边界：'用' 与加粗的 'Flutter' 之间、'r' 与 '写' 之间、'写' 与 '3'、'3' 与 '行'。
        final widenedTexts = bodyLeaves
            .where((r) => ((r.letterSpacing ?? 0) - widened).abs() < 0.001)
            .map((r) => r.text)
            .toList();
        expect(widenedTexts, const <String>['用', 'r', '写3']);

        // 标题按标题字号（h1 = fontSize * kDiaryHeadingScales[0]）计算间距。
        final headingSize = fontSize * kDiaryHeadingScales.first;
        final headingWidened = baseTracking + panguSpacingExtent(headingSize);
        final headingLeaves = _leafRuns(spanOf(tester, '第1章Intro'));
        final headingGaps = headingLeaves
            .where(
              (r) => ((r.letterSpacing ?? 0) - headingWidened).abs() < 0.001,
            )
            .map((r) => r.text)
            .toList();
        expect(headingGaps, const <String>['第1章']);
      },
    );

    testWidgets(
      'skips code blocks, inline code trailing edges, and superscripts',
      (tester) async {
        await pumpEditor(tester, <Map<String, Object?>>[
          block('code', <Map<String, Object?>>[run('中文123abc')]),
          block('paragraph', <Map<String, Object?>>[
            run('用'),
            run('Flutter', <String, Object?>{'code': true}),
            run('写'),
          ]),
          block('paragraph', <Map<String, Object?>>[
            run('注解'),
            run('1', <String, Object?>{'script': 'super'}),
            run('说明'),
          ]),
        ], typography: const DiaryTypography(fontSize: 16, panguSpacing: true));

        // 代码块完全跳过。
        final codeLeaves = _leafRuns(spanOf(tester, '中文123abc'));
        expect(codeLeaves.every((r) => (r.letterSpacing ?? 0) == 0), isTrue);

        // 行内代码：左侧 '用' 加间距，行内代码 'Flutter' 自身末尾不加间距（防止灰底拖尾）。
        final inlineCodeLeaves = _leafRuns(spanOf(tester, '用Flutter写'));
        final gap = panguSpacingExtent(16);
        expect(
          inlineCodeLeaves
              .where((r) => ((r.letterSpacing ?? 0) - gap).abs() < 0.001)
              .map((r) => r.text),
          const <String>['用'],
        );

        // 上下标：'注解' 与 '说明' 都不加盘古之白。
        for (final element
            in find
                .descendant(
                  of: find.byType(DiaryEditor),
                  matching: find.byType(RichText),
                )
                .evaluate()) {
          final span = (element.widget as RichText).text;
          final plain = span.toPlainText(includeSemanticsLabels: false);
          if (plain.contains('注解') && plain.contains('说明')) {
            final leaves = _leafRuns(span);
            expect(leaves.every((r) => (r.letterSpacing ?? 0) == 0), isTrue);
          }
        }
      },
    );

    testWidgets('coexists with first-line indent and find highlights', (
      tester,
    ) async {
      final controller = await pumpEditor(
        tester,
        <Map<String, Object?>>[
          block('paragraph', <Map<String, Object?>>[run('我用Flutter写日记')]),
        ],
        typography: const DiaryTypography(
          fontSize: 16,
          firstLineIndent: 2,
          panguSpacing: true,
        ),
      );
      final gap = panguSpacingExtent(16);

      // 开启查找高亮命中 'Flutter'：片段被切开后，'用' 与 'r' 的盘古之白依然保留。
      controller.find.open(text: 'Flutter');
      await tester.pumpAndSettle();

      final leaves =
          <({String text, double? letterSpacing, double? fontSize})>[];
      for (final element
          in find
              .descendant(
                of: find.byType(DiaryEditor),
                matching: find.byType(RichText),
              )
              .evaluate()) {
        final span = (element.widget as RichText).text;
        final plain = span.toPlainText(includeSemanticsLabels: false);
        if (plain.contains('Flutter')) {
          leaves.addAll(_leafRuns(span));
        }
      }
      expect(
        leaves
            .where((r) => ((r.letterSpacing ?? 0) - gap).abs() < 0.001)
            .map((r) => r.text),
        const <String>['用', 'r'],
      );
    });
  });

  group('DiaryPanguTextEditingController', () {
    testWidgets(
      'applies pangu spacing when enabled and suppresses IME composing range',
      (tester) async {
        final controller = DiaryPanguTextEditingController(
          text: '今天Flutter很好',
          panguSpacing: true,
        );
        addTearDown(controller.dispose);
        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                ctx = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        const style = TextStyle(fontSize: 20, letterSpacing: 0);
        final gap = panguSpacingExtent(20);

        final enabled = controller.buildTextSpan(
          context: ctx,
          style: style,
          withComposing: true,
        );
        final enabledLeaves = _leafRuns(enabled);
        expect(enabledLeaves.map((r) => r.text).join(), '今天Flutter很好');
        expect(
          enabledLeaves
              .where((r) => ((r.letterSpacing ?? 0) - gap).abs() < 0.001)
              .map((r) => r.text),
          const <String>['天', 'r'],
        );

        // 输入法组字中（"今天tianqi很好"，composing 覆盖 "tianqi"）：两侧不抖动。
        controller.value = const TextEditingValue(
          text: '今天tianqi很好',
          selection: TextSelection.collapsed(offset: 8),
          composing: TextRange(start: 2, end: 8),
        );
        final composingSpan = controller.buildTextSpan(
          context: ctx,
          style: style,
          withComposing: true,
        );
        final composingLeaves = _leafRuns(composingSpan);
        expect(
          composingLeaves.every((r) => (r.letterSpacing ?? 0) == 0),
          isTrue,
        );

        // 关闭开关时退回默认行为。
        controller.panguSpacing = false;
        controller.value = const TextEditingValue(text: '今天Flutter很好');
        final disabled = controller.buildTextSpan(
          context: ctx,
          style: style,
          withComposing: true,
        );
        expect(
          _leafRuns(disabled).every((r) => (r.letterSpacing ?? 0) == 0),
          isTrue,
        );
      },
    );
  });

  group('DiaryCard pangu spacing', () {
    DiaryWithTags sampleDiary() => DiaryWithTags(
      diary: Diary(
        id: 1,
        diaryId: 'pangu-card',
        title: '用Flutter写日记',
        content: '',
        contentText: '今天写了3段代码',
        metadata: '{}',
        createdAt: DateTime(2026, 11, 24),
        updatedAt: DateTime(2026, 11, 24),
        isArchived: false,
        isPinned: false,
        isDeleted: false,
      ),
      tags: const <Tag>[],
    );

    Future<void> pumpCard(
      WidgetTester tester, {
      required bool panguSpacing,
      List<String> highlightTerms = const <String>[],
    }) async {
      final theme = MaterialTheme(
        Typography.material2021().black,
        fonts: AppFonts(diaryPanguSpacing: panguSpacing),
      ).theme(ColorScheme.fromSeed(seedColor: const Color(0xff1e6586)));
      final resolved = DiaryCardResolvedStyle.resolve(
        style: DiaryCardStyle.defaults,
        mode: DiaryCardMode.list,
        theme: theme,
        screenWidth: 400,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: DiaryCard(
                  diary: sampleDiary(),
                  resolved: resolved,
                  selected: false,
                  isSelectionMode: false,
                  maxVisibleTags: 3,
                  enableCoverHero: false,
                  highlightTerms: highlightTerms,
                  onOpenEditor: (_, _, _) {},
                  onToggleSelection: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'applies pangu spacing to card title and preview including across '
      'search highlights',
      (tester) async {
        await pumpCard(
          tester,
          panguSpacing: true,
          highlightTerms: const <String>['Flutter'],
        );

        final titleWidget = tester.widget<RichText>(
          find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText(includeSemanticsLabels: false) ==
                    '用Flutter写日记',
          ),
        );
        final titleLeaves = _leafRuns(titleWidget.text);
        final titleBaseSpacing =
            titleLeaves.firstWhere((r) => r.text == 'Flutte').letterSpacing ??
            0;
        final titleWidened = titleLeaves
            .where((r) => (r.letterSpacing ?? 0) > titleBaseSpacing + 1.0)
            .map((r) => r.text)
            .toList();
        expect(titleWidened, const <String>['用', 'r']);

        final previewWidget = tester.widget<RichText>(
          find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText(includeSemanticsLabels: false) == '今天写了3段代码',
          ),
        );
        final previewLeaves = _leafRuns(previewWidget.text);
        final previewWidened = previewLeaves
            .where((r) => (r.letterSpacing ?? 0) > 1.0)
            .map((r) => r.text)
            .toList();
        expect(previewWidened, const <String>['了3']);
      },
    );
  });
}
