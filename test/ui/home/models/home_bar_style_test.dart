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
      // 顶栏恒为玻璃）。
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
    });

    test('round-trips every field through JSON text', () {
      const style = HomeBarStyle(
        tintOpacity: 0.55,
        tint: HomeBarTint.theme,
        topBarHairline: true,
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
    test('the bar is shorter and its items narrower without labels', () {
      for (final mode in <HomeBarLabelMode>[
        HomeBarLabelMode.always,
        HomeBarLabelMode.selected,
      ]) {
        expect(HomeBarMetrics.barHeight(mode), 60);
        expect(HomeBarMetrics.itemWidth(mode), 72);
      }
      expect(HomeBarMetrics.barHeight(HomeBarLabelMode.never), 54);
      expect(HomeBarMetrics.itemWidth(HomeBarLabelMode.never), 64);
    });

    test('an item leaves the same gap to the pill on every side', () {
      // 指示器铺满一格：格高 = 栏高 − 2 × 缝，胶囊宽 = 项宽之和 + 2 × 缝。
      expect(HomeBarMetrics.inset, 6);
      expect(HomeBarMetrics.itemHeight(60), 48);
      expect(
        HomeBarMetrics.pillWidth(4, 72),
        4 * 72 + HomeBarMetrics.inset * 2,
      );
    });

    test('items keep their width while they fit and shrink evenly after', () {
      // 四项 72 宽加两侧的缝共 300：放得下时不变。
      expect(HomeBarMetrics.fitItemWidth(72, 4, 328), 72);
      expect(HomeBarMetrics.fitItemWidth(72, 4, 300), 72);
      // 放不下：（可用宽 − 两侧的缝）平分。
      expect(HomeBarMetrics.fitItemWidth(72, 4, 256), (256 - 12) / 4);
      // 再窄也不小于最小项宽。
      expect(
        HomeBarMetrics.fitItemWidth(72, 4, 100),
        HomeBarMetrics.minItemWidth,
      );
      // 无界宽度（测试里常见）与空栏不收窄。
      expect(HomeBarMetrics.fitItemWidth(72, 4, double.infinity), 72);
      expect(HomeBarMetrics.fitItemWidth(72, 0, 10), 72);
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
