import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_layout.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';

/// 悬浮工具栏卡片宽度 = 屏宽 - 两侧各 12dp。
double _cardWidth(double screenWidth) =>
    screenWidth - 2 * kDiaryFloatingToolbarInset;

void main() {
  group('resolveDiaryToolbarLayout', () {
    test('keeps every tool on the row when they fit compactly', () {
      final items = kDefaultDiaryToolbarOrder.take(5).toList();

      final layout = resolveDiaryToolbarLayout(items, width: _cardWidth(360));

      expect(layout.hasOverflow, isFalse);
      expect(layout.pinned, items);
      expect(layout.columns, 0);
    });

    test('pins as many leading tools as fit and keeps a cell for More', () {
      // 360dp：内容宽 320，40dp 一格 + 2dp 间隔能放 7 格，最后一格给「更多」。
      final narrow = resolveDiaryToolbarLayout(
        kDefaultDiaryToolbarOrder,
        width: _cardWidth(360),
      );
      expect(narrow.columns, 7);
      expect(narrow.pinned, kDefaultDiaryToolbarOrder.take(6));
      expect(narrow.overflow, kDefaultDiaryToolbarOrder.skip(6));

      // 393 与 412dp 都是 8 格。
      for (final screenWidth in <double>[393, 412]) {
        final layout = resolveDiaryToolbarLayout(
          kDefaultDiaryToolbarOrder,
          width: _cardWidth(screenWidth),
        );
        expect(layout.columns, 8, reason: '$screenWidth');
        expect(layout.pinned, kDefaultDiaryToolbarOrder.take(7));
      }
    });

    test(
      'stops at the first tool that does not fit instead of skipping it',
      () {
        // 「缩进」占两格：剩一格时不跳过它去塞后面更窄的工具。
        final items = <DiaryToolbarItem>[
          DiaryToolbarItem.undo,
          DiaryToolbarItem.redo,
          DiaryToolbarItem.recording,
          DiaryToolbarItem.bold,
          DiaryToolbarItem.italic,
          DiaryToolbarItem.indent,
          DiaryToolbarItem.underline,
          DiaryToolbarItem.quote,
        ];

        final layout = resolveDiaryToolbarLayout(items, width: _cardWidth(360));

        expect(layout.columns, 7);
        expect(layout.pinned, items.take(5));
        expect(layout.overflow.first, DiaryToolbarItem.indent);
      },
    );

    test('flows overflow into rows of the same columns, indent spans two', () {
      final layout = resolveDiaryToolbarLayout(
        kDefaultDiaryToolbarOrder,
        width: _cardWidth(400),
      );
      expect(layout.columns, 8);

      final rows = layout.overflowRows;

      expect(rows.expand((row) => row), layout.overflow);
      for (final row in rows) {
        final slots = row.fold<int>(
          0,
          (sum, item) => sum + diaryToolbarItemSlots(item),
        );
        expect(slots, lessThanOrEqualTo(layout.columns));
      }
      expect(rows, hasLength(3));
    });

    test('measures indent as two buttons with the section gap', () {
      expect(diaryToolbarItemExtent(DiaryToolbarItem.bold), 40);
      expect(diaryToolbarItemExtent(DiaryToolbarItem.indent), 84);
    });
  });

  group('diaryToolbarOverflowBoundary', () {
    test('is null when every enabled tool fits', () {
      final hidden = kDefaultDiaryToolbarOrder.skip(4).toSet();

      expect(
        diaryToolbarOverflowBoundary(
          kDefaultDiaryToolbarOrder,
          hidden,
          width: _cardWidth(360),
        ),
        isNull,
      );
    });

    test('counts hidden tools above the line without giving them a cell', () {
      final order = kDefaultDiaryToolbarOrder;
      // 隐藏第 2 个：线上方仍是 6 个启用工具，分界下标多算上被隐藏的那一项。
      final hidden = <DiaryToolbarItem>{order[1]};

      final boundary = diaryToolbarOverflowBoundary(
        order,
        hidden,
        width: _cardWidth(360),
      );

      expect(boundary, 7);
    });
  });

  group('keepDiaryToolbarItemOnSide', () {
    final width = _cardWidth(360);
    final order = kDefaultDiaryToolbarOrder;

    List<DiaryToolbarItem> dropAt(DiaryToolbarItem moved, int newIndex) {
      final result = List<DiaryToolbarItem>.of(order)..remove(moved);
      result.insert(newIndex, moved);
      return result;
    }

    test('a pinned tool dropped just below the line moves into More', () {
      // 把“撤销”放到分界线正下方：简单插入后补位的正好是它自己。
      final reordered = dropAt(DiaryToolbarItem.undo, 5);

      final result = keepDiaryToolbarItemOnSide(
        reordered,
        moved: DiaryToolbarItem.undo,
        pinned: false,
        hiddenItems: const <DiaryToolbarItem>{},
        width: width,
      );

      final layout = resolveDiaryToolbarLayout(result, width: width);
      expect(layout.overflow.first, DiaryToolbarItem.undo);
      // 原先排在线下第一位的工具补位上来。
      expect(layout.pinned.last, order[6]);
    });

    test('an overflow tool dropped just above the line stays pinned', () {
      final moved = order[10];
      final reordered = dropAt(moved, 6);

      final result = keepDiaryToolbarItemOnSide(
        reordered,
        moved: moved,
        pinned: true,
        hiddenItems: const <DiaryToolbarItem>{},
        width: width,
      );

      final layout = resolveDiaryToolbarLayout(result, width: width);
      expect(layout.pinned.last, moved);
      // 原先常驻的最后一个被挤到线下。
      expect(layout.overflow.first, order[5]);
    });

    test('pinning the two-cell indent pushes out enough tools', () {
      final reordered = dropAt(DiaryToolbarItem.indent, 6);

      final result = keepDiaryToolbarItemOnSide(
        reordered,
        moved: DiaryToolbarItem.indent,
        pinned: true,
        hiddenItems: const <DiaryToolbarItem>{},
        width: width,
      );

      final layout = resolveDiaryToolbarLayout(result, width: width);
      expect(layout.pinned, contains(DiaryToolbarItem.indent));
      expect(
        layout.pinned.fold<int>(
          0,
          (sum, item) => sum + diaryToolbarItemSlots(item),
        ),
        lessThanOrEqualTo(layout.columns - 1),
      );
    });

    test('leaves hidden tools where they were dropped', () {
      final reordered = dropAt(DiaryToolbarItem.undo, 5);

      final result = keepDiaryToolbarItemOnSide(
        reordered,
        moved: DiaryToolbarItem.undo,
        pinned: false,
        hiddenItems: const <DiaryToolbarItem>{DiaryToolbarItem.undo},
        width: width,
      );

      expect(result, reordered);
    });
  });
}
