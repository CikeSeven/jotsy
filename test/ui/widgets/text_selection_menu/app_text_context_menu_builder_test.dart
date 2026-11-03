import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import 'text_selection_menu_test_app.dart';

/// 文字为 [text] 的输入框，聚焦并选中全部文字后打开选区菜单。
Future<void> _openMenu(
  WidgetTester tester, {
  String text = 'hello world',
  bool obscureText = false,
}) async {
  setTextMenuScreen(tester);
  final controller = TextEditingController(text: text);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    textMenuTestApp(
      Scaffold(
        body: Center(
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            contextMenuBuilder: appTextContextMenuBuilder,
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byType(TextField));
  await tester.pumpAndSettle();
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: text.length,
  );
  await tester.pump();
  tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.processText, null);
  });

  testWidgets('shows the glass capsule with share on Android', (tester) async {
    await _openMenu(tester);
    expect(find.byType(AppTextSelectionToolbar), findsOneWidget);
    expect(find.byType(AppTextContextMenuPanel), findsNothing);
    expect(find.text('复制'), findsOneWidget);
    await tester.tap(
      find.ancestor(of: find.text('更多'), matching: find.byType(TextButton)),
    );
    await tester.pumpAndSettle();
    expect(find.text('分享'), findsOneWidget);
  });

  testWidgets('offers neither share nor copy for obscured text', (
    tester,
  ) async {
    await _openMenu(tester, obscureText: true);
    expect(find.text('分享'), findsNothing);
    expect(find.text('复制'), findsNothing);
    expect(find.text('更多'), findsNothing);
  });

  testWidgets('shows the vertical menu without share on desktop', (
    tester,
  ) async {
    await _openMenu(tester);
    expect(find.byType(AppTextContextMenuPanel), findsOneWidget);
    expect(find.byType(AppTextSelectionToolbar), findsNothing);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('Ctrl+C'), findsOneWidget);
    expect(find.text('分享'), findsNothing);
    expect(find.text('Share'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('puts Android process text actions into the secondary area', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.processText, (call) async {
          if (call.method == 'ProcessText.queryTextActions') {
            return <String, String>{'translate': 'Google 翻译'};
          }
          return null;
        });
    await _openMenu(tester);
    expect(find.text('Google 翻译'), findsNothing);
    await tester.tap(
      find.ancestor(of: find.text('更多'), matching: find.byType(TextButton)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Google 翻译'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Google 翻译'),
          matching: find.byType(TextButton),
        ),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is FaIcon &&
              widget.icon == FontAwesomeIcons.arrowUpRightFromSquare.data,
        ),
      ),
      findsOneWidget,
    );
  });

  test('maps custom button items into the secondary slot', () {
    final slot = appTextMenuSlotOf(ContextMenuButtonType.custom);
    expect(slot, AppTextMenuSlot.secondary);
    expect(
      appTextMenuSlotOf(ContextMenuButtonType.copy),
      AppTextMenuSlot.primary,
    );
    expect(appTextMenuShortcutOf(ContextMenuButtonType.copy), isNull);
  });
}
