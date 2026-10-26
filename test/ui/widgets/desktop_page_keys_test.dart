import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/desktop_page_arrows.dart';

/// [DesktopPageKeys] 的 Esc：页面上开着登记了局部历史的浮层（弹出菜单）时
/// 先关掉浮层，不执行页面返回；没有时才返回。
void main() {
  testWidgets(
    'escape removes an open local history entry before leaving the page',
    (tester) async {
      var escapes = 0;
      var entryRemoved = false;
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          home: DesktopPageKeys(
            onEscape: () => escapes++,
            child: Builder(
              builder: (BuildContext context) {
                pageContext = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      ModalRoute.of(pageContext)!.addLocalHistoryEntry(
        LocalHistoryEntry(onRemove: () => entryRemoved = true),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(entryRemoved, isTrue);
      expect(escapes, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(escapes, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('touch platforms do not bind escape', (tester) async {
    var escapes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopPageKeys(
          onEscape: () => escapes++,
          child: const Focus(autofocus: true, child: SizedBox.expand()),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(escapes, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
