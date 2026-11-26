import 'package:flutter/painting.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import '../core/services/settings_service.dart';
import 'theme/app_color_scheme.dart';

/// 原生端告诉 Dart 系统闪屏用了哪一档闪屏配色的入口参数前缀，值为
/// [LaunchSplashTheme.indexFor] 的档位序号。须与 `MainActivity.kt` 一致。
const String launchSplashThemeArgPrefix = '--launch-splash-theme=';

/// 启动闪屏配色：系统闪屏的底色与品牌图形跟随主题色。
///
/// 为什么分档：系统闪屏只能画编译期资源里的主题，而主题色可以是任意颜色
/// （色板之外的颜色可经 AI 助手、备份恢复写入）。默认的 tonalSpot 配色只取
/// 种子色的 HCT 色相（主色与底色的彩度、明度固定），所以按色相分成
/// [hueSteps] 档，每档预生成一套原生闪屏主题（`launch_splash_themes.xml`，
/// 由 `test/app/launch_splash_theme_test.dart` 生成并校验），另加黑白、灰色
/// 两档；默认主题色不占档位，用清单里的 `LaunchTheme`。
///
/// 接力：Dart 在主题色变化时请原生把对应档位记成下次启动的闪屏主题
/// （Android 13+ 的 `SplashScreen.setSplashScreenTheme`）；下次启动时原生把档位
/// 经 [launchSplashThemeArgPrefix] 传回，Flutter 首帧按该档的代表种子色
/// （[seedFor]）建主题，与系统闪屏逐像素一致。设置读到后换成真正的主题色，
/// 两者色相相差不到半档，主题补间几乎看不出。
abstract final class LaunchSplashTheme {
  /// 色相档数：每档 3°，与真实主题色最多差 1.5°。
  static const int hueSteps = 120;

  /// 黑白配色（[kMonochromeThemeSeedValue]）的档位。
  static const int monochromeIndex = 0;

  /// 无彩色种子（[isAchromaticColor]）的档位：去色后的配色与种子无关。
  static const int achromaticIndex = 1;

  /// 第一档色相的序号；色相 h 落在 `firstHueIndex + round(h / 3°) % hueSteps`。
  static const int firstHueIndex = 2;

  /// 档位总数，即原生 `launch_splash_themes` 数组的长度。
  static const int count = firstHueIndex + hueSteps;

  static const double _hueStep = 360 / hueSteps;

  /// 代表种子色的彩度与明度：取 tonalSpot 浅色主色本身，色相稳定、远离灰色。
  static const double _seedChroma = 36;
  static const double _seedTone = 40;

  /// 灰色档的代表种子：色板灰色系的中间一格。
  static const int _achromaticSeedValue = 0xFF9E9E9E;

  /// [seed] 所在的档位；默认主题色返回 null（用清单里的启动主题）。
  static int? indexFor(Color seed) {
    final value = seed.toARGB32();
    if (value == SettingsService.defaultThemeSeedColorValue) {
      return null;
    }
    if (value == kMonochromeThemeSeedValue) {
      return monochromeIndex;
    }
    if (isAchromaticColor(seed)) {
      return achromaticIndex;
    }
    final hue = Hct.fromInt(value).hue;
    return firstHueIndex + (hue / _hueStep).round() % hueSteps;
  }

  /// 档位 [index] 的代表种子色：原生闪屏主题按它生成，Flutter 首帧也按它建主题。
  static Color seedFor(int index) {
    RangeError.checkValueInInterval(index, 0, count - 1, 'index');
    return switch (index) {
      monochromeIndex => const Color(kMonochromeThemeSeedValue),
      achromaticIndex => const Color(_achromaticSeedValue),
      _ => Color(
        Hct.from(
          (index - firstHueIndex) * _hueStep,
          _seedChroma,
          _seedTone,
        ).toInt(),
      ),
    };
  }

  /// 从 Dart 入口参数读出系统闪屏所用档位的代表种子色；没有该参数（系统闪屏
  /// 用的是默认主题、Android 13 以下、其他平台、测试）或档位无效时返回 null。
  static Color? seedFromEntrypointArgs(List<String> args) {
    for (final arg in args) {
      if (!arg.startsWith(launchSplashThemeArgPrefix)) {
        continue;
      }
      final index = int.tryParse(
        arg.substring(launchSplashThemeArgPrefix.length),
      );
      if (index == null || index < 0 || index >= count) {
        return null;
      }
      return seedFor(index);
    }
    return null;
  }
}
