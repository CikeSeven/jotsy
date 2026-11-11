import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_geometry.dart';

/// 四项、每项 72×56 的导航行。
const Size _row = Size(288, 56);

/// 缝为 6 时首尾最多探出的距离。
final double _room = HomeNavGeometry.edgeRoom(6);

Rect _rect(
  double position, {
  double velocity = 0,
  bool elastic = false,
  bool rtl = false,
  int count = 4,
}) => HomeNavGeometry.indicatorRect(
  size: _row,
  count: count,
  position: position,
  velocity: velocity,
  elastic: elastic,
  rtl: rtl,
  edgeRoom: _room,
);

void main() {
  group('followAmount', () {
    test('is 1 on the page, fades over one page and clamps at the ends', () {
      expect(HomeNavGeometry.followAmount(1, 1, 4), 1);
      expect(HomeNavGeometry.followAmount(1, 1.25, 4), 0.75);
      expect(HomeNavGeometry.followAmount(2, 1.25, 4), 0.25);
      expect(HomeNavGeometry.followAmount(3, 1.25, 4), 0);
      // 页面越界回弹时首尾两项保持选中。
      expect(HomeNavGeometry.followAmount(0, -0.3, 4), 1);
      expect(HomeNavGeometry.followAmount(3, 3.4, 4), 1);
    });
  });

  group('indicatorRect', () {
    test('at rest it is exactly the selected cell', () {
      expect(_rect(0), const Rect.fromLTWH(0, 0, 72, 56));
      expect(_rect(2), const Rect.fromLTWH(144, 0, 72, 56));
      expect(_rect(2, elastic: true), _rect(2));
    });

    test('between two cells it slides linearly', () {
      expect(_rect(1.5), const Rect.fromLTWH(108, 0, 72, 56));
    });

    test('a page position outside the range stops at the ends', () {
      expect(_rect(-0.4), _rect(0));
      expect(_rect(3.7), _rect(3));
      // 页面位置不带速度：给了也不拉伸。
      expect(_rect(1, velocity: 20), _rect(1));
    });

    test('a moving spring stretches it wider and a little flatter', () {
      final rect = _rect(1.5, velocity: 8, elastic: true);
      final stretch = 8 * HomeNavGeometry.stretchPerVelocity;
      expect(rect.width, closeTo(72 * (1 + stretch), 0.001));
      expect(
        rect.height,
        closeTo(56 * (1 - stretch * HomeNavGeometry.squashRatio), 0.001),
      );
      // 以中心为准，竖直方向仍居中；方向不影响拉伸量。
      expect(rect.center, const Offset(144, 28));
      expect(_rect(1.5, velocity: -8, elastic: true), rect);
    });

    test('the stretch is capped', () {
      final fast = _rect(1.5, velocity: 1000, elastic: true);
      expect(fast.width, closeTo(72 * (1 + HomeNavGeometry.maxStretch), 0.001));
    });

    test('an overshooting spring is squashed against the pill wall', () {
      // 越过最后一项 0.2 项（14.4dp）：右缘最多探出 edgeRoom，宽度被挤窄。
      final rect = _rect(3.2, elastic: true);
      expect(rect.right, _row.width + _room);
      expect(rect.width, lessThan(72));
      expect(rect.left, closeTo(3.2 * 72, 0.001));

      final start = _rect(-0.2, elastic: true);
      expect(start.left, -_room);
      expect(start.width, lessThan(72));
    });

    test('right-to-left counts the cells from the right', () {
      expect(_rect(0, rtl: true), const Rect.fromLTWH(216, 0, 72, 56));
      expect(_rect(3, rtl: true), const Rect.fromLTWH(0, 0, 72, 56));
      final rect = _rect(3.2, elastic: true, rtl: true);
      expect(rect.left, -_room);
    });

    test('the edge room leaves 1 to the pill wall and never goes negative', () {
      expect(HomeNavGeometry.edgeRoom(6), 5);
      expect(HomeNavGeometry.edgeRoom(2), 1);
      expect(HomeNavGeometry.edgeRoom(0.5), 0);
    });

    test('degenerate inputs give an empty or pinned rect', () {
      expect(_rect(0, count: 0), Rect.zero);
      // 位置远在范围之外（Tab 集合变化的那一帧）：不画出反向的矩形。
      final far = _rect(40, elastic: true);
      expect(far.width, 0);
      expect(far.right, _row.width + _room);
    });
  });
}
