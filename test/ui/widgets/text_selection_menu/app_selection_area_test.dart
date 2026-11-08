import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import 'text_selection_menu_test_app.dart';

/// 只读文字的选区（AI 回答等）：长按选字后出现应用统一的选区菜单，与输入框
/// 同一套（手机为玻璃胶囊，带复制与分享）。
void main() {
  testWidgets('long press selects and opens the app capsule menu', (
    tester,
  ) async {
    setTextMenuScreen(tester);
    await tester.pumpWidget(
      textMenuTestApp(
        const Scaffold(
          body: Center(
            child: AppSelectionArea(child: Text('hello selectable world')),
          ),
        ),
      ),
    );
    await tester.longPress(find.text('hello selectable world'));
    await tester.pumpAndSettle();
    expect(find.byType(AppTextSelectionToolbar), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    // 手机上补的「分享」在“更多”里。
    await tester.tap(
      find.ancestor(of: find.text('更多'), matching: find.byType(TextButton)),
    );
    await tester.pumpAndSettle();
    expect(find.text('分享'), findsOneWidget);
  });
}
