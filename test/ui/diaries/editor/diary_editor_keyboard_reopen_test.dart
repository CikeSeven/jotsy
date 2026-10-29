import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
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
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor_keyboard_reopen.dart';

import '../../../support/expressive_test_theme.dart';

/// 收起软键盘后点回原插入点要重新弹出键盘。上游在测试里按宿主平台走桌面
/// 选区服务（每次点按都重连输入法），复现不了手机上“选区没变就不 show”，
/// 所以这里直接把指针事件交给这一层的 Listener，模拟手机上点按后选区原样
/// 不变的情形。
void main() {
  const appearance = DiaryTextAppearance(typography: DiaryTypography());
  final caret = af.Selection.collapsed(af.Position(path: [0], offset: 3));

  Future<(DiaryEditorController, FocusNode)> pumpFocused(
    WidgetTester tester,
  ) async {
    final focus = FocusNode();
    final controller = DiaryEditorController.fromContent('正文 body text');
    controller.select(caret);
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
              focusNode: focus,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(controller.state.selection, caret);
    return (controller, focus);
  }

  // 光标闪烁让 pumpAndSettle 停不下来，卸载后再收尾。
  Future<void> unmount(
    WidgetTester tester,
    DiaryEditorController controller,
    FocusNode focus,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    controller.dispose();
    focus.dispose();
  }

  Listener listener(WidgetTester tester) => tester.widget<Listener>(
    find
        .descendant(
          of: find.byType(DiaryEditorKeyboardReopen),
          matching: find.byType(Listener),
        )
        .first,
  );

  /// 在正文上按下、可选地移动或停留，再抬起；[between] 在抬起前运行。
  Future<void> press(
    WidgetTester tester, {
    Offset move = Offset.zero,
    Duration hold = const Duration(milliseconds: 80),
    VoidCallback? between,
  }) async {
    final start =
        tester.getTopLeft(find.byType(af.AppFlowyEditor)) +
        const Offset(30, 10);
    listener(tester).onPointerDown!(
      PointerDownEvent(pointer: 7, position: start),
    );
    if (move != Offset.zero) {
      listener(tester).onPointerMove!(
        PointerMoveEvent(pointer: 7, position: start + move),
      );
    }
    await tester.pump(hold);
    between?.call();
    listener(tester).onPointerUp!(
      PointerUpEvent(pointer: 7, position: start + move),
    );
    await tester.pump();
  }

  bool reconnected(WidgetTester tester) => tester.testTextInput.log.any(
    (call) => call.method == 'TextInput.clearClient',
  );

  testWidgets('tapping the caret again shows the keyboard the user hid', (
    tester,
  ) async {
    final (controller, focus) = await pumpFocused(tester);
    final attached = Map<String, dynamic>.of(
      tester.testTextInput.editingState!,
    );
    // 用户用返回手势收起键盘：连接与焦点都还在。
    tester.testTextInput.hide();
    expect(tester.testTextInput.isVisible, isFalse);
    tester.testTextInput.log.clear();

    await press(tester);

    expect(reconnected(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    // 新连接拿到的编辑值与收起前相同，插入点不动。
    expect(tester.testTextInput.editingState, attached);
    expect(controller.state.selection, caret);
    await unmount(tester, controller, focus);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'leaves the input alone for a visible keyboard, drags, long presses '
    'and taps that moved the caret',
    (tester) async {
      final (controller, focus) = await pumpFocused(tester);

      // 键盘正显示：重连会让输入法重置面板。
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      tester.testTextInput.log.clear();
      await press(tester);
      expect(reconnected(tester), isFalse);
      tester.view.resetViewInsets();
      tester.testTextInput.hide();

      // 越过触摸容差是拖动 / 滚动。
      tester.testTextInput.log.clear();
      await press(tester, move: const Offset(0, kTouchSlop * 2));
      expect(reconnected(tester), isFalse);

      // 按到长按时长是长按选字。
      await press(tester, hold: kLongPressTimeout + kPressTimeout);
      expect(reconnected(tester), isFalse);

      // 点按换了插入点：上游已按新编辑值 show。
      final moved = af.Selection.collapsed(af.Position(path: [0], offset: 1));
      await press(tester, between: () => controller.select(moved));
      expect(reconnected(tester), isFalse);
      expect(tester.testTextInput.isVisible, isTrue);

      // 正文没有焦点（焦点在标题等别处）。
      focus.unfocus();
      await tester.pump();
      tester.testTextInput.log.clear();
      await press(tester);
      expect(reconnected(tester), isFalse);
      await unmount(tester, controller, focus);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('desktop taps never reconnect the input', (tester) async {
    final (controller, focus) = await pumpFocused(tester);
    tester.testTextInput.log.clear();
    await press(tester);
    expect(reconnected(tester), isFalse);
    await unmount(tester, controller, focus);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
