import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_resolved_style.dart';

import '../../../support/expressive_test_theme.dart';

/// 解析层的玻璃与页面底色：对比度按卡片实际叠在的颜色计算，玻璃参数进入
/// 表面规格。
void main() {
  setUp(DiaryCardResolvedStyle.debugClearCache);
  // 复用按主题实例（identical）判断，所有用例共用同一份主题。
  final theme = expressiveTestTheme(Brightness.light);

  DiaryCardResolvedStyle resolve(DiaryCardStyle style, {Color? page}) =>
      DiaryCardResolvedStyle.resolve(
        style: style,
        mode: DiaryCardMode.list,
        theme: theme,
        screenWidth: 360,
        pageBackground: page,
      );

  group('page background', () {
    const faint = DiaryCardStyle(surface: DiaryCardSurfaceStyle(opacity: 0.2));

    test('defaults to the theme page color (previous behavior)', () {
      final resolved = resolve(faint);
      expect(resolved.pageBackground, resolved.colorScheme.surface);
      final appearance = resolved.appearanceFor(pinned: false, locked: false);
      expect(appearance.inverted, isFalse);
      expect(appearance.titleColor, resolved.colorScheme.onSurface);
    });

    test('a dark estimated backdrop flips text to readable colors', () {
      final resolved = resolve(faint, page: const Color(0xFF121212));
      final appearance = resolved.appearanceFor(pinned: false, locked: false);
      expect(appearance.inverted, isTrue);
      expect(appearance.titleColor, resolved.colorScheme.onInverseSurface);
    });

    test('is part of the reuse key', () {
      final light = resolve(faint);
      final dark = resolve(faint, page: const Color(0xFF121212));
      expect(identical(light, dark), isFalse);
      expect(
        identical(resolve(faint, page: const Color(0xFF121212)), dark),
        isTrue,
      );
      // 显式传入主题页面底色与缺省相同，复用同一结果。
      expect(
        identical(resolve(faint, page: light.pageBackground), light),
        isTrue,
      );
    });
  });

  group('glass surface spec', () {
    test('solid cards carry no glass parameters', () {
      final spec = resolve(
        DiaryCardStyle.defaults,
      ).appearanceFor(pinned: false, locked: false).surface;
      expect(spec.glass, isFalse);
      expect(spec.blurSigma, 0);
    });

    test('glass is always translucent and keeps its blur', () {
      // 不透明度 1 的玻璃：投影仍只画外侧，免得从底下透出。
      const style = DiaryCardStyle(
        surface: DiaryCardSurfaceStyle(
          material: DiaryCardMaterial.glass,
          blurSigma: 18,
          shadow: DiaryCardShadowStyle.soft,
        ),
      );
      final spec = resolve(
        style,
      ).appearanceFor(pinned: false, locked: false).surface;
      expect(spec.glass, isTrue);
      expect(spec.blurSigma, 18);
      expect(spec.shadows, isNotEmpty);
      expect(
        spec.shadows.every((shadow) => shadow.blurStyle == BlurStyle.outer),
        isTrue,
      );
    });

    test('a directly constructed out-of-range blur is clamped', () {
      const style = DiaryCardStyle(
        surface: DiaryCardSurfaceStyle(
          material: DiaryCardMaterial.glass,
          blurSigma: 90,
        ),
      );
      final spec = resolve(
        style,
      ).appearanceFor(pinned: false, locked: false).surface;
      expect(spec.blurSigma, DiaryCardStyleLimits.blurSigma.max);
    });
  });
}
