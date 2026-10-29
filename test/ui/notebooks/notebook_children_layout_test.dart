import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_children_layout.dart';

/// 头部子本网格的列数与折叠规则。
void main() {
  group('columnsFor', () {
    test('phones get two columns even when cells end up narrow', () {
      expect(NotebookChildrenLayout.columnsFor(256), 2); // 320dp 手机
      expect(NotebookChildrenLayout.columnsFor(336), 2);
    });

    test('wider cards add columns of at least 160dp up to six', () {
      expect(NotebookChildrenLayout.columnsFor(496), 3);
      expect(NotebookChildrenLayout.columnsFor(664), 4);
      expect(NotebookChildrenLayout.columnsFor(2000), 6);
    });

    test('an unbounded width falls back to two columns', () {
      expect(NotebookChildrenLayout.columnsFor(double.infinity), 2);
    });
  });

  group('folding', () {
    test('children that fit in two rows are all listed', () {
      final layout = NotebookChildrenLayout.of(
        width: 336,
        count: 4,
        expanded: false,
      );
      expect(layout.collapsible, isFalse);
      expect(layout.shown, 4);
      expect(layout.hidden, 0);
    });

    test('more children keep two rows with the last cell for the rest', () {
      final layout = NotebookChildrenLayout.of(
        width: 336,
        count: 9,
        expanded: false,
      );
      expect(layout.columns, 2);
      expect(layout.collapsible, isTrue);
      expect(layout.shown, 3);
      expect(layout.hidden, 6);
      expect(layout.cellWidth, 164);
    });

    test('expanding lists every child and keeps the toggle cell', () {
      final layout = NotebookChildrenLayout.of(
        width: 664,
        count: 9,
        expanded: true,
      );
      expect(layout.columns, 4);
      expect(layout.collapsible, isTrue);
      expect(layout.shown, 9);
      expect(layout.hidden, 0);
    });

    test('expanded state does not matter when everything fits', () {
      final layout = NotebookChildrenLayout.of(
        width: 664,
        count: 8,
        expanded: true,
      );
      expect(layout.collapsible, isFalse);
      expect(layout.shown, 8);
    });
  });
}
