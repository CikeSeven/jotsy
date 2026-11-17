import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_deck_entries.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_deck_layout.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_tree.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';

/// 日记本卡组的条目（分组、子本展开、当前本子的上级链）与几何（叠放、
/// 压叠、拉开、命中）。
void main() {
  var nextId = 0;
  NotebookRow row(
    String name, {
    String? parentId,
    bool pinned = false,
    bool closed = false,
    NotebookKind kind = NotebookKind.manual,
  }) {
    final id = 'nb${nextId++}';
    return NotebookRow(
      id: nextId,
      notebookId: id,
      name: name,
      kind: kind.name,
      visibility: NotebookVisibility.normal.name,
      payload: '{}',
      sortOrder: nextId,
      isPinned: pinned,
      isClosed: closed,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      parentId: parentId,
    );
  }

  List<NotebookView> views(List<NotebookRow> rows) =>
      NotebookTree(rows).notebooks;

  List<String> names(List<NotebookDeckEntry> entries) => <String>[
    for (final e in entries)
      switch (e.kind) {
        NotebookDeckEntryKind.all => '全部',
        NotebookDeckEntryKind.unfiled => '未收录',
        NotebookDeckEntryKind.closedHeader => '已合上',
        NotebookDeckEntryKind.notebook =>
          '${'  ' * e.depth}${e.notebook!.name}',
      },
  ];

  group('entries', () {
    late NotebookRow travel;
    late NotebookRow japan;
    late NotebookRow tokyo;
    late List<NotebookRow> rows;

    setUp(() {
      nextId = 0;
      travel = row('旅行');
      japan = row('日本', parentId: travel.notebookId);
      tokyo = row('东京', parentId: japan.notebookId);
      rows = <NotebookRow>[
        travel,
        japan,
        tokyo,
        row('置顶', pinned: true),
        row('智能', kind: NotebookKind.smart),
        row('旧本', closed: true),
      ];
    });

    List<NotebookDeckEntry> build({
      Set<String> expanded = const <String>{},
      String? current,
    }) {
      final notebooks = views(rows);
      final tree = NotebookTree.fromViews(notebooks);
      // 与卡组一样：打开时把露出当前本子要展开的项并进展开状态。
      return buildNotebookDeckEntries(
        notebooks: notebooks,
        tree: tree,
        expanded: <String>{
          ...expanded,
          ...notebookDeckRevealKeys(
            notebooks: notebooks,
            tree: tree,
            currentNotebookId: current,
          ),
        },
      );
    }

    test('scope cards first, then pinned / mine / smart, closed last', () {
      expect(names(build()), <String>[
        '全部',
        '未收录',
        '置顶',
        '旅行',
        '智能',
        '已合上',
        '旧本',
      ]);
    });

    test('a parent shows its children only once expanded', () {
      final collapsed = build();
      final parent = collapsed.firstWhere((e) => e.notebook?.name == '旅行');
      expect(parent.childCount, 1);
      expect(parent.expanded, isFalse);

      final open = build(expanded: <String>{'m:${travel.notebookId}'});
      expect(names(open), containsAllInOrder(<String>['旅行', '  日本']));
      expect(names(open), isNot(contains('    东京')));
      final child = open.firstWhere((e) => e.notebook?.name == '日本');
      expect(child.parentKey, 'm:${travel.notebookId}');
      expect(child.key, 'm:${travel.notebookId}/${japan.notebookId}');
    });

    test('the current sub-notebook unfolds its ancestors', () {
      final entries = build(current: tokyo.notebookId);
      expect(
        names(entries),
        containsAllInOrder(<String>['旅行', '  日本', '    东京']),
      );
      expect(
        notebookDeckRevealKeys(
          notebooks: views(rows),
          tree: NotebookTree.fromViews(views(rows)),
          currentNotebookId: tokyo.notebookId,
        ),
        <String>{'m:${travel.notebookId}', 'm:${japan.notebookId}'},
      );
    });

    test('closed notebooks keep their entries while the pile is folded', () {
      final folded = build();
      final header = folded.firstWhere(
        (e) => e.kind == NotebookDeckEntryKind.closedHeader,
      );
      expect(header.expanded, isFalse);
      expect(header.closedCount, 1);
      final open = build(expanded: const <String>{'c'});
      expect(open.last.inClosedGroup, isTrue);
      expect(
        open
            .firstWhere((e) => e.kind == NotebookDeckEntryKind.closedHeader)
            .expanded,
        isTrue,
      );
    });
  });

  group('layout', () {
    List<NotebookDeckEntry> plain(int count) {
      nextId = 0;
      final rows = <NotebookRow>[for (var i = 0; i < count; i++) row('本$i')];
      final notebooks = views(rows);
      return buildNotebookDeckEntries(
        notebooks: notebooks,
        tree: NotebookTree.fromViews(notebooks),
        expanded: const <String>{},
      );
    }

    test('cards overlap by the band and the last one shows in full', () {
      final entries = plain(3);
      final layout = NotebookDeckLayout(entries);
      expect(layout.tops.first, NotebookDeckLayout.topPadding);
      for (var i = 1; i < entries.length; i++) {
        expect(layout.tops[i] - layout.tops[i - 1], NotebookDeckLayout.peek);
      }
      expect(
        layout.extent,
        layout.tops.last +
            NotebookDeckLayout.cardHeight +
            NotebookDeckLayout.bottomPadding,
      );
    });

    test('cards scrolled past the top pile up instead of leaving', () {
      final first = NotebookDeckLayout.place(
        index: 0,
        count: 5,
        top: NotebookDeckLayout.topPadding,
        scroll: NotebookDeckLayout.peek * 2,
        maxScroll: 500,
      );
      expect(
        first.y,
        NotebookDeckLayout.topPadding - 2 * NotebookDeckLayout.pileStep,
      );
      expect(first.scale, closeTo(1 - 2 * NotebookDeckLayout.pileShrink, 1e-9));
      expect(first.opacity, 1);

      final deep = NotebookDeckLayout.place(
        index: 0,
        count: 5,
        top: NotebookDeckLayout.topPadding,
        scroll: NotebookDeckLayout.peek * 5,
        maxScroll: 500,
      );
      expect(deep.opacity, 0);
      expect(deep.y, greaterThanOrEqualTo(0));
    });

    test('overscrolling spreads the gaps instead of moving rigidly', () {
      double y(int index) => NotebookDeckLayout.place(
        index: index,
        count: 5,
        top: NotebookDeckLayout.topPadding + index * NotebookDeckLayout.peek,
        scroll: -100,
        maxScroll: 300,
      ).y;
      final gaps = <double>[for (var i = 1; i < 5; i++) y(i) - y(i - 1)];
      for (final gap in gaps) {
        expect(gap, greaterThan(NotebookDeckLayout.peek));
      }
      // 最近的一张只跟一部分。
      expect(
        y(0) - NotebookDeckLayout.topPadding,
        closeTo(100 * NotebookDeckLayout.spreadNear, 1e-9),
      );
    });

    test('hit testing returns the card painted on top', () {
      final rects = <Rect>[
        const Rect.fromLTWH(0, 0, 100, 120),
        const Rect.fromLTWH(0, 60, 100, 120),
      ];
      expect(notebookDeckHitTest(const Offset(10, 90), rects, <int>[0, 1]), 1);
      expect(notebookDeckHitTest(const Offset(10, 30), rects, <int>[0, 1]), 0);
      expect(
        notebookDeckHitTest(const Offset(10, 300), rects, <int>[0, 1]),
        -1,
      );
    });
  });
}
