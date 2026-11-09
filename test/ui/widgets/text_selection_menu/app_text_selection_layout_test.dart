import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_selection_layout.dart';

const _screen = Size(360, 800);
const _menu = Size(200, 64);

AppTextToolbarGeometry _geometry({
  required Offset primary,
  Offset? secondary,
  EdgeInsets safe = EdgeInsets.zero,
  double? softBottom,
  double minExpandedHeight = 0,
}) => AppTextToolbarGeometry(
  overlaySize: _screen,
  safePadding: safe,
  primaryAnchor: primary,
  secondaryAnchor: secondary,
  collapsedHeight: _menu.height,
  softBottom: softBottom,
  minExpandedHeight: minExpandedHeight,
);

void main() {
  group('AppTextToolbarGeometry', () {
    test('places the menu 8dp above the first selection rect by default', () {
      final geometry = _geometry(
        primary: const Offset(180, 400),
        secondary: const Offset(180, 460),
      );
      expect(geometry.above, isTrue);
      final offset = geometry.offsetFor(_menu);
      expect(offset.dy + _menu.height, 400 - 8);
      expect(offset.dx + _menu.width / 2, 180);
      expect(geometry.availableHeight, 400 - 8 - 8);
    });

    test('flips below the last rect plus 20dp when there is no room above', () {
      final geometry = _geometry(
        primary: const Offset(180, 60),
        secondary: const Offset(120, 100),
        safe: const EdgeInsets.only(top: 24),
      );
      expect(geometry.above, isFalse);
      final offset = geometry.offsetFor(_menu);
      expect(offset.dy, 100 + 20);
      // 在下方时按末个矩形居中。
      expect(offset.dx + _menu.width / 2, 120);
      expect(geometry.availableHeight, 800 - 8 - 120);
    });

    test('stays above when the top edge lands exactly on the margin', () {
      final geometry = _geometry(primary: const Offset(180, 8 + 64 + 8));
      expect(geometry.above, isTrue);
      expect(geometry.offsetFor(_menu).dy, 8);
    });

    test('clamps horizontally into the safe area on both edges', () {
      const safe = EdgeInsets.only(left: 30, right: 40);
      final left = _geometry(primary: const Offset(10, 400), safe: safe);
      expect(left.offsetFor(_menu).dx, 30 + 8);
      final right = _geometry(primary: const Offset(355, 400), safe: safe);
      expect(right.offsetFor(_menu).dx, 360 - 40 - 8 - _menu.width);
      expect(left.availableWidth, 360 - 30 - 40 - 16);
    });

    test('clamps into the screen when neither side has room', () {
      final geometry = _geometry(
        primary: const Offset(180, 40),
        secondary: const Offset(180, 790),
      );
      expect(geometry.above, isFalse);
      expect(geometry.offsetFor(_menu).dy, 800 - 8 - _menu.height);
    });

    test('falls back to the primary anchor without a secondary anchor', () {
      final geometry = _geometry(primary: const Offset(180, 30));
      expect(geometry.offsetFor(_menu).dy, 30 + 20);
    });
  });

  // 内容底部浮层（日记编辑页的悬浮工具栏与面板）的上沿，#221。
  group('AppTextToolbarGeometry with a soft bottom', () {
    test('a menu above the selection keeps its room', () {
      final geometry = _geometry(
        primary: const Offset(180, 300),
        softBottom: 320,
      );
      expect(geometry.above, isTrue);
      expect(geometry.offsetFor(_menu).dy + _menu.height, 300 - 8);
      expect(geometry.availableHeight, 300 - 8 - 8);
    });

    test('a collapsed menu below the selection stays above the layer', () {
      final geometry = _geometry(
        primary: const Offset(180, 40),
        secondary: const Offset(180, 60),
        softBottom: 140,
        minExpandedHeight: 120,
      );
      expect(geometry.above, isFalse);
      // 下方放不下整个菜单：往上夹进浮层上沿以上，不盖浮层。
      expect(geometry.offsetFor(_menu).dy, 140 - 8 - _menu.height);
    });

    test('an expansion that fits grows only down to the layer', () {
      final geometry = _geometry(
        primary: const Offset(180, 40),
        secondary: const Offset(180, 60),
        softBottom: 400,
        minExpandedHeight: 120,
      );
      expect(geometry.availableHeight, 400 - 8 - (60 + 20));
      const expanded = Size(240, 200);
      expect(geometry.offsetFor(expanded).dy, 60 + 20);
    });

    test('an expansion without room for one row may cover the layer', () {
      final geometry = _geometry(
        primary: const Offset(180, 40),
        secondary: const Offset(180, 60),
        safe: const EdgeInsets.only(bottom: 300),
        softBottom: 160,
        minExpandedHeight: 120,
      );
      // 到浮层为止只有 160 − 8 − 80 = 72，不够一行次要项：展开可以长到
      // 键盘上沿，主行留在原处。
      expect(geometry.availableHeight, 800 - 300 - 8 - 80);
      const expanded = Size(240, 200);
      expect(geometry.offsetFor(expanded).dy, 60 + 20);
      // 收起时仍守在浮层上沿以上（72 放得下收起的 64）。
      final collapsed = geometry.offsetFor(_menu).dy;
      expect(collapsed, 60 + 20);
      expect(collapsed + _menu.height, lessThanOrEqualTo(160 - 8));
    });
  });

  group('fitAppTextToolbarRow', () {
    test('keeps every item when the row fits', () {
      final fit = fitAppTextToolbarRow<String>(
        items: <String>['a', 'b', 'c'],
        widths: <double>[56, 56, 56],
        moreWidth: 56,
        hasSecondary: false,
        available: 200,
        chrome: 8,
      );
      expect(fit.row, <String>['a', 'b', 'c']);
      expect(fit.overflow, isEmpty);
    });

    test('moves trailing items out and reserves room for the more button', () {
      final fit = fitAppTextToolbarRow<String>(
        items: <String>['a', 'b', 'c', 'd'],
        widths: <double>[56, 56, 56, 56],
        moreWidth: 56,
        hasSecondary: false,
        available: 200,
        chrome: 8,
      );
      // 8 + 56×2 + 56（更多）= 176 ≤ 200；三项加更多为 232。
      expect(fit.row, <String>['a', 'b']);
      expect(fit.overflow, <String>['c', 'd']);
    });

    test('counts the more button when secondary items already exist', () {
      final fit = fitAppTextToolbarRow<String>(
        items: <String>['a', 'b', 'c'],
        widths: <double>[56, 56, 56],
        moreWidth: 56,
        hasSecondary: true,
        available: 200,
        chrome: 8,
      );
      expect(fit.row, <String>['a', 'b']);
      expect(fit.overflow, <String>['c']);
    });

    test('always keeps at least one item in the row', () {
      final fit = fitAppTextToolbarRow<String>(
        items: <String>['a', 'b'],
        widths: <double>[56, 56],
        moreWidth: 56,
        hasSecondary: true,
        available: 60,
      );
      expect(fit.row, <String>['a']);
      expect(fit.overflow, <String>['b']);
    });
  });
}
