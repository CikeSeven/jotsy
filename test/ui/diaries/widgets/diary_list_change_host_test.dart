import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/widgets/diary_list_change_host.dart';
import 'package:node_diary/ui/widgets/list_make_room.dart';

/// 日记列表的数据变化动效：换位滑动、移除先退场再让位、新项入场，以及
/// 翻页、宿主自己收起、减少动画时不做动效。
void main() {
  const duration = Duration(milliseconds: 250);
  late DiaryListChangeFrame frame;
  late ScrollController scroll;

  Future<void> pumpList(
    WidgetTester tester,
    List<String> ids, {
    Set<String> pendingHide = const <String>{},
    Set<String> appearing = const <String>{},
    Set<String> hidden = const <String>{},
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: scroll,
            slivers: <Widget>[
              DiaryListChangeHost(
                diaries: <DiaryWithTags>[for (final id in ids) _diary(id)],
                duration: duration,
                pendingHideDiaryIds: pendingHide,
                appearingDiaryIds: appearing,
                hiddenDiaryIds: hidden,
                builder: (BuildContext context, DiaryListChangeFrame value) {
                  frame = value;
                  return MakeRoomSliverList(
                    makeRoom: value.makeRoom,
                    delegate: SliverChildBuilderDelegate((
                      BuildContext context,
                      int index,
                    ) {
                      final id = value.items[index].diary.diaryId;
                      return KeyedSubtree(
                        key: ValueKey<String>('list_$id'),
                        child: MakeRoomItem(
                          tag: id,
                          controller: value.makeRoom!,
                          child: SizedBox(
                            key: ValueKey<String>('box_$id'),
                            height: 100,
                            child: Text(id),
                          ),
                        ),
                      );
                    }, childCount: value.items.length),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  double topOf(WidgetTester tester, String id) =>
      tester.getTopLeft(find.byKey(ValueKey<String>('box_$id'))).dy;

  List<String> idsOf(DiaryListChangeFrame frame) => <String>[
    for (final item in frame.items) item.diary.diaryId,
  ];

  setUp(() => scroll = ScrollController());
  tearDown(() => scroll.dispose());

  testWidgets('moved items start where they were and spring into place', (
    tester,
  ) async {
    await pumpList(tester, <String>['a', 'b', 'c']);
    final aBefore = topOf(tester, 'a');
    final cBefore = topOf(tester, 'c');

    await pumpList(tester, <String>['c', 'a', 'b']);
    // 新布局已排好的第一帧仍画在原位置，不先闪一下新布局。
    expect(topOf(tester, 'c'), moreOrLessEquals(cBefore));
    expect(topOf(tester, 'a'), moreOrLessEquals(aBefore));
    expect(frame.makeRoom!.isActive, isTrue);

    // 弹簧在那一帧画完后起步，下一帧开始计时。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(topOf(tester, 'c'), lessThan(cBefore));
    expect(topOf(tester, 'c'), greaterThan(aBefore));

    await tester.pumpAndSettle();
    expect(topOf(tester, 'c'), moreOrLessEquals(aBefore));
    expect(topOf(tester, 'a'), moreOrLessEquals(aBefore + 100));
    expect(frame.makeRoom!.isActive, isFalse);
  });

  testWidgets('a removed item exits in place before the rest close the gap', (
    tester,
  ) async {
    await pumpList(tester, <String>['a', 'b', 'c']);
    final bBefore = topOf(tester, 'b');
    final cBefore = topOf(tester, 'c');

    await pumpList(tester, <String>['a', 'c']);
    expect(idsOf(frame), <String>['a', 'b', 'c']);
    expect(frame.exiting, <String>{'b'});
    expect(frame.sourceIndexOf(1), isNull);
    expect(frame.sourceIndexOf(2), 1);
    expect(topOf(tester, 'c'), moreOrLessEquals(cBefore));

    await tester.pump(duration);
    await tester.pump();
    // 退场项拿掉后，下面的项从原位置滑上来，而不是跳上来。
    expect(idsOf(frame), <String>['a', 'c']);
    expect(frame.exiting, isEmpty);
    expect(topOf(tester, 'c'), greaterThan(bBefore));

    await tester.pumpAndSettle();
    expect(topOf(tester, 'c'), moreOrLessEquals(bBefore));
  });

  testWidgets('an exiting item that comes back stays in the list', (
    tester,
  ) async {
    await pumpList(tester, <String>['a', 'b', 'c']);
    await pumpList(tester, <String>['a', 'c']);
    expect(frame.exiting, <String>{'b'});

    await pumpList(tester, <String>['a', 'b', 'c']);
    expect(idsOf(frame), <String>['a', 'b', 'c']);
    expect(frame.exiting, isEmpty);

    await tester.pumpAndSettle();
    expect(idsOf(frame), <String>['a', 'b', 'c']);
  });

  testWidgets('items the host animated out or hid leave without exiting', (
    tester,
  ) async {
    await pumpList(tester, <String>['a', 'b', 'c'], pendingHide: {'b'});
    await pumpList(tester, <String>['a', 'c']);
    expect(idsOf(frame), <String>['a', 'c']);
    expect(frame.exiting, isEmpty);

    await pumpList(tester, <String>['c'], hidden: {'a'});
    expect(idsOf(frame), <String>['c']);
    expect(frame.exiting, isEmpty);
  });

  testWidgets('new items in the built range enter; the marks clear later', (
    tester,
  ) async {
    await pumpList(tester, <String>['a', 'b']);
    await pumpList(tester, <String>['x', 'a', 'y', 'b'], appearing: {'y'});
    // y 由宿主自己演出现，不重复。
    expect(frame.entering, <String>{'x'});

    await tester.pump(duration);
    expect(frame.entering, isEmpty);
  });

  testWidgets('appending a page neither moves nor enters anything', (
    tester,
  ) async {
    await pumpList(tester, <String>['a', 'b']);
    await pumpList(tester, <String>['a', 'b', 'c', 'd']);
    expect(frame.entering, isEmpty);
    expect(frame.makeRoom!.isActive, isFalse);
  });

  testWidgets('scrolling in the same frame is not mistaken for movement', (
    tester,
  ) async {
    await pumpList(tester, <String>[for (var i = 0; i < 20; i++) 'd$i']);
    scroll.jumpTo(160);
    // 同一帧既滚动又换数据（顺序没变）：按内容坐标量，没有位移。
    await pumpList(tester, <String>[for (var i = 0; i < 20; i++) 'd$i']);
    expect(frame.makeRoom!.isActive, isFalse);
  });

  testWidgets('reduced motion swaps the list at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpList(tester, <String>['a', 'b', 'c']);
    await pumpList(tester, <String>['c', 'a']);
    expect(idsOf(frame), <String>['c', 'a']);
    expect(frame.exiting, isEmpty);
    expect(frame.makeRoom!.isActive, isFalse);
  });
}

DiaryWithTags _diary(String id) => DiaryWithTags(
  diary: Diary(
    id: id.hashCode,
    diaryId: id,
    title: id,
    content: '[]',
    contentText: id,
    metadata: '{}',
    createdAt: DateTime(2026, 11, 19),
    updatedAt: DateTime(2026, 11, 19),
    isArchived: false,
    isPinned: false,
    isDeleted: false,
  ),
  tags: const <Tag>[],
);
