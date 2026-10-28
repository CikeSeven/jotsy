import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card_context_menu.dart';
import 'package:node_diary/ui/diaries/widgets/diary_swipe_action_item.dart';

import 'diaries_wide_test_support.dart';

/// 桌面上日记卡片的右键菜单：右键在指针处打开、项目齐全、置顶走数据库写入；
/// 手机上没有右键菜单。
List<DiaryWithTags> _diaries(String prefix, int count, {DateTime? unlockAt}) =>
    <DiaryWithTags>[
      for (var index = 0; index < count; index++)
        wideDiary(prefix, index, unlockAt: index == 0 ? unlockAt : null),
    ];

Future<void> _rightClick(WidgetTester tester, Finder finder) async {
  await tester.tap(
    finder,
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

const List<String> _allItems = <String>[
  'Edit',
  'Pin',
  'Add to notebook…',
  'Archive',
  'Delete',
];

void main() {
  testWidgets('right-clicking a card opens the menu and pin pins it', (
    tester,
  ) async {
    final store = await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('menu', 3),
    );

    await _rightClick(tester, wideCard('menu title 1'));
    for (final label in _allItems) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // 菜单的起始角贴着指针（卡片中心）。
    final cardCenter = tester.getCenter(wideCard('menu title 1'));
    final menuTop = tester.getTopLeft(
      find
          .ancestor(
            of: find.byType(MenuItemButton).first,
            matching: find.byType(Material),
          )
          .first,
    );
    expect(menuTop.dx, moreOrLessEquals(cardCenter.dx));
    expect(menuTop.dy, moreOrLessEquals(cardCenter.dy));

    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(store.pinned, <String>{'menu-1'});
    expect(find.byType(MenuItemButton), findsNothing);

    await unmountWideDiariesPage(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a sealed time capsule has no edit item', (tester) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('capsule', 2, unlockAt: DateTime(2099)),
    );

    await _rightClick(tester, wideListCards.first);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Pin'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await unmountWideDiariesPage(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('delete from the menu confirms, deletes and offers undo', (
    tester,
  ) async {
    final store = await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('menudel', 3),
    );

    await _rightClick(tester, wideCard('menudel title 2'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.deleted, <String>{'menudel-2'});

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.restored, <String>{'menudel-2'});

    await unmountWideDiariesPage(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('the context-menu key opens the menu on the focused card', (
    tester,
  ) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('menukey', 2),
    );

    // 卡片 InkWell 自己的焦点（相当于 Tab 移到卡片上）。
    final cardFocus = find
        .descendant(
          of: find
              .descendant(
                of: wideCard('menukey title 0'),
                matching: find.byType(InkWell),
              )
              .first,
          matching: find.byType(Focus),
        )
        .first;
    // ignore: avoid_dynamic_calls
    ((tester.state(cardFocus) as dynamic).focusNode as FocusNode)
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(Focus.of(tester.element(find.text('Edit'))).hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);

    await unmountWideDiariesPage(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('phones have no card context menu', (tester) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(400, 800),
      diaries: _diaries('phone', 2),
    );
    expect(find.byType(DiaryCardContextMenu), findsNothing);
    await unmountWideDiariesPage(tester);
  });

  testWidgets('desktop cards have no swipe-to-archive', (tester) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(800, 800),
      diaries: _diaries('noswipe', 2),
    );
    expect(find.byType(DiarySwipeActionItem), findsNothing);
    await unmountWideDiariesPage(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('android cards keep swipe-to-archive', (tester) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(400, 800),
      diaries: _diaries('swipe', 2),
    );
    expect(find.byType(DiarySwipeActionItem), findsNWidgets(2));
    await unmountWideDiariesPage(tester);
  });
}
