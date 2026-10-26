import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_detail_pane/diary_detail_pane.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/widgets/empty_hint.dart';

import 'diaries_wide_test_support.dart';

Finder _inPane(Finder finder) =>
    find.descendant(of: find.byType(DiaryDetailPane), matching: finder);

List<DiaryWithTags> _diaries(String prefix, int count) => <DiaryWithTags>[
  for (var index = 0; index < count; index++) wideDiary(prefix, index),
];

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// 列表里标题为 [title] 的卡片的位置。
Rect _cardRect(WidgetTester tester, String title) =>
    tester.getRect(wideCard(title));

void main() {
  testWidgets('arrow keys move the selection through the list order', (
    tester,
  ) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('arrows', 6),
    );

    await tester.tap(wideCard('arrows title 0'));
    await tester.pumpAndSettle();
    expect(_inPane(find.text('arrows title 0')), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_inPane(find.text('arrows title 1')), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_inPane(find.text('arrows title 2')), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_inPane(find.text('arrows title 1')), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_inPane(find.text('arrows title 0')), findsOneWidget);
    // 第一篇再往上不动。
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_inPane(find.text('arrows title 0')), findsOneWidget);

    await unmountWideDiariesPage(tester);
  });

  testWidgets('escape clears the selection', (tester) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('escape', 3),
    );

    await tester.tap(wideCard('escape title 1'));
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.escape);
    expect(_inPane(find.byType(EmptyHint)), findsOneWidget);

    // 没有选中时方向键从第一篇开始。
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_inPane(find.text('escape title 0')), findsOneWidget);

    await unmountWideDiariesPage(tester);
  });

  testWidgets('moving the selection keeps the selected card in view', (
    tester,
  ) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('visible', 15),
    );

    await tester.tap(wideCard('visible title 0'));
    await tester.pumpAndSettle();
    for (var step = 0; step < 10; step++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_inPane(find.text('visible title 10')), findsOneWidget);
    final down = _cardRect(tester, 'visible title 10');
    expect(down.bottom, lessThanOrEqualTo(800));
    expect(down.top, greaterThanOrEqualTo(0));

    // 往回走时卡片不被固定的标签栏挡住。
    for (var step = 0; step < 8; step++) {
      await _press(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(_inPane(find.text('visible title 2')), findsOneWidget);
    final up = _cardRect(tester, 'visible title 2');
    final tagBar = tester.getRect(find.byType(DiaryTagFilterBar));
    expect(up.top, greaterThanOrEqualTo(tagBar.bottom - 0.5));
    expect(up.bottom, lessThanOrEqualTo(800));

    await unmountWideDiariesPage(tester);
  });

  testWidgets('moving past the loaded end loads the next page and goes on', (
    tester,
  ) async {
    // 首屏 20 篇，共 25 篇：第 20 篇（序号 19）之后要先加载下一页。
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('paging', 25),
    );

    await tester.tap(wideCard('paging title 0'));
    await tester.pumpAndSettle();
    for (var step = 0; step < 20; step++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_inPane(find.text('paging title 20')), findsOneWidget);
    for (var step = 0; step < 4; step++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_inPane(find.text('paging title 24')), findsOneWidget);
    // 真正的末尾：停住。
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_inPane(find.text('paging title 24')), findsOneWidget);

    await unmountWideDiariesPage(tester);
  });

  testWidgets('the next page loads on demand when nothing scrolled', (
    tester,
  ) async {
    // 窗口高到整个首屏都放得下：列表不滚动，不会顺带触发加载下一页，
    // 只能由方向键移过末尾时去加载。
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 6000),
      diaries: _diaries('demand', 23),
    );
    expect(find.text('demand title 20'), findsNothing);

    await tester.tap(wideCard('demand title 19'));
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_inPane(find.text('demand title 20')), findsOneWidget);

    await unmountWideDiariesPage(tester);
  });

  testWidgets('enter opens the editor for the selected entry', (tester) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('enter', 3),
    );

    // 没有选中时 Enter 不做事。
    await _press(tester, LogicalKeyboardKey.enter);
    expect(find.byType(EditDiaryPage), findsNothing);

    await tester.tap(wideCard('enter title 1'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // 编辑器获得焦点后光标闪烁，pumpAndSettle 不会结束：固定出帧。
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final editor = tester.widget<EditDiaryPage>(find.byType(EditDiaryPage));
    expect(editor.diaryId, 'enter-1');
    expect(editor.entryMode, EditDiaryEntryMode.edit);

    await unmountWideDiariesPage(tester);
  });

  testWidgets('arrow keys do nothing in a single-pane window', (tester) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(900, 700),
      diaries: _diaries('single', 3),
    );
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.byType(DiaryDetailPane), findsNothing);
    await unmountWideDiariesPage(tester);
  });
}
