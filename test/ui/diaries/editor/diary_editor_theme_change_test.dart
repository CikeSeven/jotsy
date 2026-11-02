import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';

import '../../../support/expressive_test_theme.dart';

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}

/// 正文里包含 [text] 的那一行实际绘制的文字颜色（读画出来的 RichText，
/// 编辑器缓存了过期的 EditorStyle 时也能发现）。
Color _renderedColor(WidgetTester tester, String text) {
  final line = tester
      .widgetList<RichText>(
        find.descendant(
          of: find.byType(DiaryEditor),
          matching: find.byType(RichText),
        ),
      )
      .firstWhere((rich) => rich.text.toPlainText().contains(text));
  Color? color;
  line.text.visitChildren((span) {
    if (span is TextSpan && (span.text?.contains(text) ?? false)) {
      color = span.style?.color;
      return false;
    }
    return true;
  });
  return color ?? line.text.style!.color!;
}

/// 正文放在 [Scaffold] 里的最小应用；[duration] 为 MaterialApp 的主题补间时长。
Widget _app({
  required DiaryEditorController controller,
  required Brightness brightness,
  Duration duration = ExpressiveMotion.fast,
  FocusNode? focusNode,
}) => ProviderScope(
  overrides: [diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle())],
  child: MaterialApp(
    themeAnimationDuration: duration,
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
        focusNode: focusNode,
        appearance: const DiaryTextAppearance(typography: DiaryTypography()),
      ),
    ),
  ),
);

void main() {
  // 应用切换明暗时 MaterialApp 按 themeAnimationDuration 补间主题（减少动画时
  // 为 0，直接换），而 Scaffold 的 Material 另用 AnimatedDefaultTextStyle 把
  // 正文的 DefaultTextStyle 补间约 200ms、不受减少动画影响。两种时长下打开着
  // 的编辑器都必须停在新主题的正文色上。
  for (final (label, duration) in <(String, Duration)>[
    ('with the theme animation', ExpressiveMotion.fast),
    ('when motion is reduced', Duration.zero),
  ]) {
    testWidgets('an open editor repaints its text in the new theme $label', (
      tester,
    ) async {
      final controller = DiaryEditorController.fromContent(
        '晚霞把整片海都染成了橘色\n带上相机',
        readOnly: true,
      );
      addTearDown(controller.dispose);
      Future<void> pump(Brightness brightness) async {
        await tester.pumpWidget(
          _app(
            controller: controller,
            brightness: brightness,
            duration: duration,
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(Brightness.light);
      final light = expressiveTestTheme(Brightness.light).colorScheme;
      expect(_renderedColor(tester, '晚霞'), light.onSurface);

      await pump(Brightness.dark);
      final dark = expressiveTestTheme(Brightness.dark).colorScheme;
      expect(_renderedColor(tester, '晚霞'), dark.onSurface);
      expect(_renderedColor(tester, '带上相机'), dark.onSurface);

      await pump(Brightness.light);
      expect(_renderedColor(tester, '晚霞'), light.onSurface);
      expect(tester.takeException(), isNull);
    });
  }

  // 补间期间每帧换上新的上游编辑器 widget：它必须就地更新（同一个
  // EditorState、同一组服务 State），编辑页开着时切换明暗不能丢掉光标、
  // 输入法连接与撤销记录。
  testWidgets('switching the theme keeps the caret, input and undo history', (
    tester,
  ) async {
    final focus = FocusNode();
    final controller = DiaryEditorController.fromContent('正文 body text');
    final caret = af.Selection.collapsed(af.Position(path: [0], offset: 3));
    controller.select(caret);
    await tester.pumpWidget(
      _app(
        controller: controller,
        brightness: Brightness.light,
        focusNode: focus,
      ),
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);

    // 经输入法打字。编辑值由输入法自己记着（上游打完字不回写，测试的
    // editingState 只反映框架发出的值），这里像真的键盘一样自己累积：换
    // 主题期间连接若被重建或回写了别的值，之后的输入就会对不上。
    final attached = tester.testTextInput.editingState!;
    var ime = TextEditingValue(
      text: attached['text'] as String,
      selection: TextSelection.collapsed(
        offset: attached['selectionBase'] as int,
      ),
    );
    void type(String text) {
      final at = ime.selection.baseOffset;
      ime = TextEditingValue(
        text: ime.text.replaceRange(at, at, text),
        selection: TextSelection.collapsed(offset: at + text.length),
      );
      tester.testTextInput.updateEditingValue(ime);
    }

    // 先打一个字：有了撤销记录，光标停在它后面。
    type('A');
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.plainText, '正文 Abody text');
    final typed = af.Selection.collapsed(af.Position(path: [0], offset: 4));
    expect(controller.selection, typed);
    final undoDepth = controller.state.undoManager.undoStack.length;
    expect(undoDepth, greaterThan(0));

    final editorState = tester.state(find.byType(af.AppFlowyEditor));
    final keyboard = controller.state.service.keyboardServiceKey.currentState;
    final selection = controller.state.service.selectionServiceKey.currentState;
    expect(keyboard, isNotNull);
    tester.testTextInput.log.clear();

    await tester.pumpWidget(
      _app(
        controller: controller,
        brightness: Brightness.dark,
        focusNode: focus,
      ),
    );
    // 逐帧走完主题与正文样式两段补间（光标闪烁让 pumpAndSettle 停不下来），
    // 并确认补间期间确实换过多次上游编辑器 widget（否则本用例没测到什么）。
    final editors = Set<Widget>.identity();
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      editors.add(tester.widget(find.byType(af.AppFlowyEditor)));
      expect(controller.selection, typed);
      expect(focus.hasFocus, isTrue);
    }
    expect(editors.length, greaterThan(2));
    final dark = expressiveTestTheme(Brightness.dark).colorScheme;
    expect(_renderedColor(tester, '正文'), dark.onSurface);

    // 上游编辑器与它的服务都是就地更新，不是重新挂载。
    expect(tester.state(find.byType(af.AppFlowyEditor)), same(editorState));
    expect(
      controller.state.service.keyboardServiceKey.currentState,
      same(keyboard),
    );
    expect(
      controller.state.service.selectionServiceKey.currentState,
      same(selection),
    );
    // 输入法连接没有断开重连，撤销记录原样。
    expect(
      tester.testTextInput.log.map((call) => call.method),
      isNot(
        anyOf(
          contains('TextInput.clearClient'),
          contains('TextInput.setClient'),
        ),
      ),
    );
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(controller.state.undoManager.undoStack.length, undoDepth);

    // 换完主题接着打字仍落在光标处，撤销照常。
    type('B');
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.plainText, '正文 ABbody text');
    controller.undo();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.plainText, isNot(contains('B')));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    controller.dispose();
    focus.dispose();
    expect(tester.takeException(), isNull);
  });
}
