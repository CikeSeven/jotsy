import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_comment_image_layout.dart';

void main() {
  const gap = DiaryCommentImageLayout.gap;
  const outer = Radius.circular(DiaryCommentImageLayout.outerRadius);
  const inner = Radius.circular(DiaryCommentImageLayout.innerRadius);

  DiaryCommentImageLayout layout(
    int count, {
    double width = 300,
    double? aspect,
  }) => DiaryCommentImageLayout.compute(
    count: count,
    availableWidth: width,
    singleAspect: aspect,
  );

  test('nothing to lay out gives an empty group', () {
    expect(layout(0).size, Size.zero);
    expect(layout(3, width: 0).tiles, isEmpty);
  });

  group('one photo keeps its shape within limits', () {
    test('landscape fills the width up to the cap', () {
      final single = layout(1, aspect: 4 / 3).tiles.single.rect;
      expect(single.width, DiaryCommentImageLayout.singleMaxExtent);
      expect(single.height, closeTo(210, 0.01));
    });

    test('portrait is capped by height', () {
      final single = layout(1, aspect: 9 / 16).tiles.single.rect;
      // 比 3:4 还竖的按 3:4。
      expect(single.height, DiaryCommentImageLayout.singleMaxExtent);
      expect(single.width, closeTo(210, 0.01));
    });

    test('panoramas are clamped to 16:9 and unknown is 4:3', () {
      final wide = layout(1, aspect: 5).tiles.single.rect;
      expect(wide.width / wide.height, closeTo(16 / 9, 0.001));
      final unknown = layout(1).tiles.single.rect;
      expect(unknown.width / unknown.height, closeTo(4 / 3, 0.001));
    });

    test('a narrow column shrinks it', () {
      final narrow = layout(1, width: 200, aspect: 1).tiles.single.rect;
      expect(narrow.size, const Size(200, 200));
      expect(layout(1).tiles.single.radius, BorderRadius.circular(14));
    });
  });

  test('three photos: a big square on the left, two on the right', () {
    final result = layout(3);
    final cell = (300 - 2 * gap) / 3;
    expect(result.size.width, 300);
    expect(result.size.height, closeTo(2 * cell + gap, 0.001));
    final [big, top, bottom] = result.tiles.map((t) => t.rect).toList();
    expect(big.width, closeTo(big.height, 0.001));
    expect(top.left, closeTo(big.right + gap, 0.001));
    expect(bottom.top, closeTo(top.bottom + gap, 0.001));
    expect(bottom.bottom, closeTo(big.bottom, 0.001));
    // 外圈大圆角，朝内的角小圆角。
    expect(
      result.tiles[0].radius,
      const BorderRadius.only(
        topLeft: outer,
        bottomLeft: outer,
        topRight: inner,
        bottomRight: inner,
      ),
    );
    expect(
      result.tiles[1].radius,
      const BorderRadius.only(
        topRight: outer,
        topLeft: inner,
        bottomLeft: inner,
        bottomRight: inner,
      ),
    );
  });

  test('every count fills the group width without overlaps', () {
    for (var count = 2; count <= 9; count++) {
      final result = layout(count, width: 296);
      expect(result.tiles, hasLength(count), reason: '$count photos');
      for (final tile in result.tiles) {
        expect(tile.rect.left, greaterThanOrEqualTo(0));
        expect(tile.rect.right, lessThanOrEqualTo(296.0001));
        expect(
          tile.rect.bottom,
          lessThanOrEqualTo(result.size.height + 0.0001),
        );
      }
      for (var i = 0; i < count; i++) {
        for (var j = i + 1; j < count; j++) {
          final overlap = result.tiles[i].rect.intersect(result.tiles[j].rect);
          expect(
            overlap.width <= 0 || overlap.height <= 0,
            isTrue,
            reason: '$count photos: tiles $i and $j overlap',
          );
        }
      }
      // 每一行最右边的格子贴齐右缘。
      expect(
        result.tiles.map((t) => t.rect.right).reduce((a, b) => a > b ? a : b),
        296,
      );
    }
  });

  test('four photos: a 2:1 banner above three squares', () {
    final rects = layout(4).tiles.map((t) => t.rect).toList();
    expect(rects[0].width, 300);
    expect(rects[0].height, 150);
    expect(rects[1].width, closeTo(rects[1].height, 0.001));
  });

  test('the group is capped on wide windows', () {
    expect(
      layout(9, width: 900).size.width,
      DiaryCommentImageLayout.maxGroupWidth,
    );
  });

  test('more than nine photos fold into a +N on the last tile', () {
    final result = layout(12);
    expect(result.tiles, hasLength(9));
    expect(result.tiles.last.overflow, 3);
    expect(result.tiles.take(8).every((t) => t.overflow == 0), isTrue);
  });
}
