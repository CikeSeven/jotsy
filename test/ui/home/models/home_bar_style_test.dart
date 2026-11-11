import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_metrics.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';

void main() {
  group('HomeBarStyle defaults', () {
    test('are neutral glass with labels and the button above the bar', () {
      const style = HomeBarStyle.defaults;
      expect(style.tint, HomeBarTint.neutral);
      expect(style.tintOpacity, 0.5);
      expect(style.topBarHairline, isFalse);
      expect(style.roundness, 1);
      expect(style.itemWidth, 72);
      expect(style.itemInset, 6);
      expect(style.itemIconSize, 22);
      expect(style.itemLabelSize, 11);
      expect(style.itemLabelGap, 3);
      expect(style.labelMode, HomeBarLabelMode.always);
      expect(style.fabPlacement, HomeBarFabPlacement.above);
      expect(style.isDefault, isTrue);
      expect(style.toJson(), isEmpty);
    });
  });

  group('HomeBarStyle.fromJson', () {
    test('returns defaults for non-map input', () {
      for (final raw in <Object?>[null, 'x', 3, <Object>[]]) {
        expect(HomeBarStyle.fromJson(raw), HomeBarStyle.defaults);
      }
    });

    test('decodes each field independently of bad neighbours', () {
      final style = HomeBarStyle.fromJson(<String, Object?>{
        'tintOpacity': 0.35,
        'tint': 'theme',
        'topBarHairline': 'nope',
        'fabPlacement': 7,
        'labelMode': 'selected',
      });
      expect(style.tintOpacity, 0.35);
      expect(style.tint, HomeBarTint.theme);
      expect(style.topBarHairline, isFalse);
      expect(style.fabPlacement, HomeBarFabPlacement.above);
      expect(style.labelMode, HomeBarLabelMode.selected);
    });

    test('clamps the opacity to its limits and rejects NaN', () {
      double opacity(Object? raw) => HomeBarStyle.fromJson(<String, Object?>{
        'tintOpacity': raw,
      }).tintOpacity;
      expect(opacity(0.0), HomeBarStyleLimits.tintOpacity.min);
      expect(opacity(5), HomeBarStyleLimits.tintOpacity.max);
      expect(opacity(double.nan), HomeBarStyle.defaults.tintOpacity);
      expect(opacity('0.5'), HomeBarStyle.defaults.tintOpacity);
    });

    test('decodes the shape and item fields and clamps them', () {
      final style = HomeBarStyle.fromJson(<String, Object?>{
        'roundness': 0.4,
        'itemWidth': 200,
        'itemInset': 1,
        'itemIconSize': 24,
        'itemLabelSize': '12',
        'itemLabelGap': double.nan,
      });
      expect(style.roundness, 0.4);
      expect(style.itemWidth, HomeBarStyleLimits.itemWidth.max);
      expect(style.itemInset, HomeBarStyleLimits.itemInset.min);
      expect(style.itemIconSize, 24);
      expect(style.itemLabelSize, HomeBarStyle.defaults.itemLabelSize);
      expect(style.itemLabelGap, HomeBarStyle.defaults.itemLabelGap);
    });

    test('falls back on unknown enum names', () {
      final style = HomeBarStyle.fromJson(<String, Object?>{
        'tint': 'rainbow',
        'labelMode': 'sometimes',
        'fabPlacement': 'below',
      });
      expect(style, HomeBarStyle.defaults);
    });

    test('ignores the fields older versions wrote', () {
      // 旧版本的一套玻璃样式：留下的字段照常读取，移除的几何、描边、
      // 指示器、自定义色调与顶栏玻璃开关全部忽略（自定义色调回退中性，
      // 顶栏恒为玻璃）。旧的 cornerRadius / iconSize / labelGap 是按另一套
      // 栏高存的，新的形状字段用了新键名，不会把它们读进来。
      final style = HomeBarStyle.fromJson(<String, Object?>{
        'material': 'glass',
        'glassTopBars': false,
        'blurSigma': 30,
        'tintOpacity': 0.45,
        'tint': 'custom',
        'tintColor': '#FF0000',
        'border': false,
        'borderLine': <String, Object?>{'color': 'highlight', 'width': 2},
        'topBarHairline': true,
        'topBarLine': <String, Object?>{'opacity': 0.9},
        'shadow': false,
        'barHeight': 80,
        'cornerRadius': 8,
        'sideMargin': 0,
        'bottomGap': 30,
        'iconSize': 28,
        'indicator': 'capsule',
        'labelGap': 10,
        'blockPadding': 12,
        'labelMode': 'never',
        'fabPlacement': 'inline',
      });
      expect(
        style,
        const HomeBarStyle(
          tintOpacity: 0.45,
          topBarHairline: true,
          labelMode: HomeBarLabelMode.never,
          fabPlacement: HomeBarFabPlacement.inline,
        ),
      );
      // 再写出去只剩留下的字段。
      expect(style.toJson().keys, <String>{
        'tintOpacity',
        'topBarHairline',
        'fabPlacement',
        'labelMode',
      });
    });
  });

  group('HomeBarStyle.toJson', () {
    test('writes only fields that differ from the defaults', () {
      expect(
        const HomeBarStyle(tint: HomeBarTint.theme).toJson(),
        <String, Object>{'tint': 'theme'},
      );
      expect(const HomeBarStyle(tintOpacity: 0.2).toJson(), <String, Object>{
        'tintOpacity': 0.2,
      });
      expect(
        const HomeBarStyle(roundness: 0.5, itemIconSize: 24).toJson(),
        <String, Object>{'roundness': 0.5, 'itemIconSize': 24.0},
      );
    });

    test('round-trips every field through JSON text', () {
      const style = HomeBarStyle(
        tintOpacity: 0.55,
        tint: HomeBarTint.theme,
        topBarHairline: true,
        roundness: 0.35,
        itemWidth: 80,
        itemInset: 4,
        itemIconSize: 20,
        itemLabelSize: 12.5,
        itemLabelGap: 5,
        fabPlacement: HomeBarFabPlacement.inline,
        labelMode: HomeBarLabelMode.selected,
      );
      final decoded = HomeBarStyle.fromJson(
        jsonDecode(jsonEncode(style.toJson())),
      );
      expect(decoded, style);
      expect(decoded.hashCode, style.hashCode);
    });

    test('copyWith changes one field and keeps the rest', () {
      const style = HomeBarStyle(tintOpacity: 0.5, topBarHairline: true);
      expect(
        style.copyWith(labelMode: HomeBarLabelMode.never),
        const HomeBarStyle(
          tintOpacity: 0.5,
          topBarHairline: true,
          labelMode: HomeBarLabelMode.never,
        ),
      );
      expect(style.copyWith(), style);
    });
  });

  group('HomeBarMetrics', () {
    test('the item height is the content plus fixed padding', () {
      // 显示文字：图标框 + 间距 + 文字行高 + 上下各 4，取整。
      expect(
        HomeBarMetrics.itemHeight(iconSize: 22, labelSize: 11, labelGap: 3),
        48,
      );
      expect(
        HomeBarMetrics.itemHeight(iconSize: 18, labelSize: 10, labelGap: 0),
        40,
      );
      // 只有图标：图标框 + 上下各 9。
      expect(HomeBarMetrics.itemHeight(iconSize: 22), 42);
      expect(HomeBarMetrics.itemHeight(iconSize: 18), 38);
    });

    test('the largest content still fits at 1.3x text scaling', () {
      // 文字最多放大到 1.3 倍：多出的高度不超过上下留白之和。
      const limits = HomeBarStyleLimits.itemLabelSize;
      final extra = limits.max * HomeBarMetrics.labelLineHeight * 0.3;
      expect(extra, lessThan(HomeBarMetrics.labeledContentPadding * 2));
    });

    test('the pill is the items plus the inset on both sides', () {
      expect(HomeBarMetrics.pillWidth(4, 72, 6), 4 * 72 + 6 * 2);
      expect(HomeBarMetrics.pillWidth(3, 60, 10), 3 * 60 + 10 * 2);
    });

    test('items keep their width while they fit and shrink evenly after', () {
      double fit(double available, {double inset = 6, int count = 4}) =>
          HomeBarMetrics.fitItemWidth(72, count, available, inset: inset);
      // 四项 72 宽加两侧的缝共 300：放得下时不变。
      expect(fit(328), 72);
      expect(fit(300), 72);
      // 放不下：（可用宽 − 两侧的缝）平分；缝越宽项越窄。
      expect(fit(256), (256 - 12) / 4);
      expect(fit(256, inset: 10), (256 - 20) / 4);
      // 再窄也不小于最小项宽。
      expect(fit(100), HomeBarMetrics.minItemWidth);
      // 无界宽度（测试里常见）与空栏不收窄。
      expect(fit(double.infinity), 72);
      expect(fit(10, count: 0), 72);
    });

    test('the pill sits just above the gesture bar but never on the edge', () {
      // 有手势条：手势条之上再留 4。
      expect(HomeBarMetrics.bottomSpace(20), 24);
      expect(HomeBarMetrics.bottomSpace(48), 52);
      // 没有手势条（实体按键、桌面窄窗口）：至少离屏幕底边 12。
      expect(HomeBarMetrics.bottomSpace(0), HomeBarMetrics.minBottomSpace);
      expect(HomeBarMetrics.bottomSpace(4), HomeBarMetrics.minBottomSpace);
    });
  });

  group('HomeBarBehavior', () {
    test('defaults to off and encodes sparsely', () {
      expect(HomeBarBehavior.defaults.hideOnScroll, isFalse);
      expect(HomeBarBehavior.defaults.indicatorFollowsSwipe, isFalse);
      expect(HomeBarBehavior.defaults.toJson(), isEmpty);
      expect(
        const HomeBarBehavior(hideOnScroll: true).toJson(),
        <String, Object>{'hideOnScroll': true},
      );
    });

    test('decodes tolerantly and round-trips', () {
      expect(HomeBarBehavior.fromJson('x'), HomeBarBehavior.defaults);
      final behavior = HomeBarBehavior.fromJson(<String, Object?>{
        'hideOnScroll': 'yes',
        'indicatorFollowsSwipe': true,
      });
      expect(behavior.hideOnScroll, isFalse);
      expect(behavior.indicatorFollowsSwipe, isTrue);
      expect(HomeBarBehavior.fromJson(behavior.toJson()), behavior);
      expect(
        behavior.copyWith(hideOnScroll: true),
        const HomeBarBehavior(hideOnScroll: true, indicatorFollowsSwipe: true),
      );
    });
  });
}
