import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card.dart';
import 'package:node_diary/ui/diaries/widgets/diary_detail_pane/diary_detail_pane.dart';

import 'diaries_wide_test_support.dart';

/// 桌面上的修饰键点按多选（Ctrl / Shift + 点按）与双栏里的 Delete 键。
List<DiaryWithTags> _diaries(String prefix, int count) => <DiaryWithTags>[
  for (var index = 0; index < count; index++) wideDiary(prefix, index),
];

/// 当前被勾选的卡片标题（按列表顺序）。
List<String> _selectedTitles(WidgetTester tester) => <String>[
  for (final card in tester.widgetList<DiaryCard>(wideListCards))
    if (card.selected) card.diary.diary.title,
];

Finder _inPane(String text) => find.descendant(
  of: find.byType(DiaryDetailPane),
  matching: find.text(text),
);

Future<void> _clickWith(
  WidgetTester tester,
  Finder card,
  LogicalKeyboardKey modifier,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.tap(card, kind: PointerDeviceKind.mouse);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ctrl+click enters multi-select and toggles cards', (
    tester,
  ) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('ctrl', 4),
    );

    await _clickWith(
      tester,
      wideCard('ctrl title 1'),
      LogicalKeyboardKey.controlLeft,
    );
    expect(_selectedTitles(tester), <String>['ctrl title 1']);
    // 勾选不是阅读：右栏仍是空的。
    expect(_inPane('ctrl title 1'), findsNothing);

    await _clickWith(
      tester,
      wideCard('ctrl title 3'),
      LogicalKeyboardKey.controlLeft,
    );
    expect(_selectedTitles(tester), <String>['ctrl title 1', 'ctrl title 3']);
    await _clickWith(
      tester,
      wideCard('ctrl title 1'),
      LogicalKeyboardKey.controlLeft,
    );
    expect(_selectedTitles(tester), <String>['ctrl title 3']);

    // 多选模式下普通点按仍是切换勾选。
    await tester.tap(wideCard('ctrl title 0'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(_selectedTitles(tester), <String>['ctrl title 0', 'ctrl title 3']);

    await unmountWideDiariesPage(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('shift+click selects the range from the last clicked card', (
    tester,
  ) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('range', 6),
    );

    await _clickWith(
      tester,
      wideCard('range title 4'),
      LogicalKeyboardKey.controlLeft,
    );
    await _clickWith(
      tester,
      wideCard('range title 1'),
      LogicalKeyboardKey.shiftLeft,
    );
    expect(_selectedTitles(tester), <String>[
      'range title 1',
      'range title 2',
      'range title 3',
      'range title 4',
    ]);

    await unmountWideDiariesPage(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a plain click still selects the diary for reading', (
    tester,
  ) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('plain', 3),
    );

    await tester.tap(wideCard('plain title 2'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(_selectedTitles(tester), isEmpty);
    expect(_inPane('plain title 2'), findsOneWidget);

    await unmountWideDiariesPage(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('modifier clicks do nothing special on phones', (tester) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(400, 800),
      diaries: _diaries('phonectrl', 3),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(wideCard('phonectrl title 1'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    // 手机上照常打开预览页，不进入多选。
    expect(_selectedTitles(tester), isEmpty);
    await unmountWideDiariesPage(tester);
  });

  testWidgets('delete key deletes the selected diary after confirming', (
    tester,
  ) async {
    final store = await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('delkey', 3),
    );

    await tester.tap(wideCard('delkey title 1'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // 取消时什么都不删。
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.deleted, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.deleted, <String>{'delkey-1'});
    // 选中移到下一篇，并给撤销。
    expect(_inPane('delkey title 2'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await unmountWideDiariesPage(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
