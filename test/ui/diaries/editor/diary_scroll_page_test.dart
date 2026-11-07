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

import '../../../support/expressive_test_theme.dart';

Map<String, Object?> _block(String type, String text) => {
  'type': type,
  'data': {
    'delta': [
      {'insert': text},
    ],
  },
};

String _document(List<Map<String, Object?>> children) => jsonEncode({
  'document': {'type': 'page', 'children': children},
});

Finder _text(String text) => find.text(text, findRichText: true);

void main() {
  const appearance = DiaryTextAppearance(typography: DiaryTypography());

  Future<void> pump(
    WidgetTester tester,
    DiaryEditorController controller,
  ) async {
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
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // 编辑页的正文铺满 Scaffold 的 body：键盘弹起时 body 逐帧变矮。
          home: Scaffold(
            body: DiaryEditor(controller: controller, appearance: appearance),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester, DiaryEditorController c) async {
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  }

  testWidgets(
    'keyboard animation keeps the visible blocks instead of rebuilding them',
    (tester) async {
      final controller = DiaryEditorController.fromContent(
        _document([
          for (var i = 0; i < 12; i++) _block('paragraph', 'line $i'),
        ]),
      );
      await pump(tester, controller);
      final elementBefore = tester.element(_text('line 0'));

      var blockBuilds = 0;
      debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
        if (element.widget is af.ParagraphBlockComponentWidget) blockBuilds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      // 键盘逐帧升起：视口逐帧变矮，上游列表的 LayoutBuilder 每帧都重建。
      for (final inset in <double>[60, 120, 180, 240, 300]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump(const Duration(milliseconds: 16));
      }
      debugOnRebuildDirtyWidget = null;

      expect(blockBuilds, 0);
      expect(identical(tester.element(_text('line 0')), elementBefore), isTrue);
      await unmount(tester, controller);
    },
  );

  testWidgets('blocks still follow edits and sibling changes after the '
      'viewport height changed', (tester) async {
    final controller = DiaryEditorController.fromContent(
      _document([
        _block('numbered_list', 'one'),
        _block('numbered_list', 'two'),
      ]),
    );
    await pump(tester, controller);
    // 先让列表按新高度重建一次，记住各项。
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('2.'), findsOneWidget);

    // 块自己的文字变化照常刷新。
    final second = controller.document.root.children[1];
    controller.apply(controller.state.transaction..insertText(second, 3, '!'));
    await tester.pumpAndSettle();
    expect(_text('two!'), findsOneWidget);

    // 前面插入同类列表项：页面块重建，记忆失效，后面的序号跟着变。
    controller.apply(
      controller.state.transaction..insertNode([
        0,
      ], af.numberedListNode(delta: af.Delta()..insert('zero'))),
    );
    await tester.pumpAndSettle();
    expect(_text('zero'), findsOneWidget);
    for (final label in ['1.', '2.', '3.']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // 键盘收起后同样如此。
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.text('3.'), findsOneWidget);
    await unmount(tester, controller);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
