import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/launch_brand_mark.dart';
import 'package:node_diary/app/launch_splash_theme.dart';
import 'package:node_diary/app/theme/app_color_scheme.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/widgets/color_palette_families.dart';

// 系统闪屏的各档主题（android/app/src/main/res/values{,-night}/launch_splash_themes.xml）
// 由这里按 LaunchSplashTheme 的代表种子色生成：底色与品牌图形颜色取该种子色在
// 应用主题下的页面底色与主色，与 Flutter 启动首帧逐像素一致。改了档位或配色
// 算法时这里会失败，用
//   flutter test test/app/launch_splash_theme_test.dart \
//     --dart-define=UPDATE_LAUNCH_SPLASH_THEMES=true
// 重新生成。

const _update = bool.fromEnvironment('UPDATE_LAUNCH_SPLASH_THEMES');
const _res = 'android/app/src/main/res';
const _lightPath = '$_res/values/launch_splash_themes.xml';
const _darkPath = '$_res/values-night/launch_splash_themes.xml';
// XML 注释里不能出现两个连字符，这里不写完整命令，只指向测试文件。
const _generatedNotice = '''
  由 test/app/launch_splash_theme_test.dart 生成，勿手改。改了档位或配色算法后
  按该文件顶部的命令（dart-define UPDATE_LAUNCH_SPLASH_THEMES=true）重新生成。''';

/// 档位的资源名后缀：黑白、灰色与按度数命名的色相档。
String _slotName(int index) {
  switch (index) {
    case LaunchSplashTheme.monochromeIndex:
      return 'mono';
    case LaunchSplashTheme.achromaticIndex:
      return 'gray';
  }
  final hueStep = index - LaunchSplashTheme.firstHueIndex;
  final degrees = hueStep * 360 ~/ LaunchSplashTheme.hueSteps;
  return 'hue${degrees.toString().padLeft(3, '0')}';
}

String _styleName(int index) {
  final slot = _slotName(index);
  return 'LaunchSplashTheme.${slot[0].toUpperCase()}${slot.substring(1)}';
}

String _hex(Color color) {
  final rgb = (color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '#${rgb.toUpperCase()}';
}

/// 启动首帧在 [seed] 的主题下画的底色与品牌图形颜色。
({Color background, Color mark}) _launchColors(
  Color seed,
  Brightness brightness,
) {
  final theme = buildSeededAppTheme(seed, brightness);
  return (
    background: theme.scaffoldBackgroundColor,
    mark: theme.colorScheme.primary,
  );
}

String _colors(Brightness brightness) {
  final buffer = StringBuffer();
  for (var i = 0; i < LaunchSplashTheme.count; i++) {
    final colors = _launchColors(LaunchSplashTheme.seedFor(i), brightness);
    final slot = _slotName(i);
    buffer
      ..writeln(
        '    <color name="launch_splash_${slot}_background">'
        '${_hex(colors.background)}</color>',
      )
      ..writeln(
        '    <color name="launch_splash_${slot}_mark">'
        '${_hex(colors.mark)}</color>',
      );
  }
  return buffer.toString();
}

String _expectedLight() {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln('<!--')
    ..writeln('  按主题色分档的系统闪屏主题，档位见 lib/app/launch_splash_theme.dart；')
    ..writeln(
      '  Android 13+ 经 SplashScreen.setSplashScreenTheme 选用'
      '（LaunchSplashThemeChannel.kt）。',
    )
    ..writeln('  每档的底色与品牌图形颜色是该档代表种子色的页面底色与主色，与 Flutter')
    ..writeln('  启动首帧一致；暗色在 values-night 的同名文件。')
    ..writeln()
    ..writeln(_generatedNotice)
    ..writeln('-->')
    ..writeln('<resources xmlns:tools="http://schemas.android.com/tools">')
    ..writeln('    <!-- 下标即档位序号（LaunchSplashTheme.indexFor），顺序不能改。 -->')
    ..writeln('    <array name="launch_splash_themes">');
  for (var i = 0; i < LaunchSplashTheme.count; i++) {
    buffer.writeln('        <item>@style/${_styleName(i)}</item>');
  }
  buffer.writeln('    </array>');
  // 放在默认目录（数组在 Kotlin 里引用，须有默认资源），但只在 Android 13+ 经
  // setSplashScreenTheme 选用：标上 targetApi，闪屏属性不算越级使用。
  for (var i = 0; i < LaunchSplashTheme.count; i++) {
    final slot = _slotName(i);
    buffer
      ..writeln(
        '    <style name="${_styleName(i)}" parent="LaunchTheme" '
        'tools:targetApi="31">',
      )
      ..writeln(
        '        <item name="android:windowSplashScreenBackground">'
        '@color/launch_splash_${slot}_background</item>',
      )
      ..writeln(
        '        <item name="launchBrandMarkColor">'
        '@color/launch_splash_${slot}_mark</item>',
      )
      ..writeln('    </style>');
  }
  buffer
    ..write(_colors(Brightness.light))
    ..writeln('</resources>');
  return buffer.toString();
}

String _expectedDark() {
  return (StringBuffer()
        ..writeln('<?xml version="1.0" encoding="utf-8"?>')
        ..writeln('<!--')
        ..writeln(
          '  系统闪屏各档主题的暗色底色与品牌图形颜色，主题与浅色见 '
          'values/launch_splash_themes.xml。',
        )
        ..writeln()
        ..writeln(_generatedNotice)
        ..writeln('-->')
        ..writeln('<resources>')
        ..write(_colors(Brightness.dark))
        ..writeln('</resources>'))
      .toString();
}

/// 两色在 sRGB 各通道上的最大差（0–255）。
double _channelDistance(Color a, Color b) {
  return <double>[
        (a.r - b.r).abs(),
        (a.g - b.g).abs(),
        (a.b - b.b).abs(),
      ].reduce(math.max) *
      255;
}

void main() {
  const defaultSeed = Color(SettingsService.defaultThemeSeedColorValue);

  test('the default theme color keeps the manifest launch theme', () {
    // 清单里的 LaunchTheme 就是默认主题色的配色，与首帧一致由
    // node_diary_app_bootstrap_test.dart 校验。
    expect(LaunchSplashTheme.indexFor(defaultSeed), isNull);
  });

  test('black and gray theme colors get their own slots', () {
    expect(
      LaunchSplashTheme.indexFor(const Color(kMonochromeThemeSeedValue)),
      LaunchSplashTheme.monochromeIndex,
    );
    for (final gray in kColorPaletteFamilies.last.colors) {
      expect(
        LaunchSplashTheme.indexFor(gray),
        LaunchSplashTheme.achromaticIndex,
      );
    }
  });

  test('every slot seed falls back into its own slot', () {
    for (var i = 0; i < LaunchSplashTheme.count; i++) {
      expect(LaunchSplashTheme.indexFor(LaunchSplashTheme.seedFor(i)), i);
    }
    expect(() => LaunchSplashTheme.seedFor(-1), throwsRangeError);
    expect(
      () => LaunchSplashTheme.seedFor(LaunchSplashTheme.count),
      throwsRangeError,
    );
  });

  test('a theme color launches with colors indistinguishable from its own', () {
    // 首帧先按档位的代表种子色画，设置读到后补间到真正的主题色：两者必须
    // 看不出差别。色板外的任意颜色同理（色相最多差半档）。
    final seeds = <Color>[
      for (final family in kThemeColorPaletteFamilies) ...family.colors,
      for (var hue = 0; hue < 360; hue += 7)
        HSVColor.fromAHSV(1, hue.toDouble(), 0.7, 0.8).toColor(),
    ];
    for (final seed in seeds) {
      final index = LaunchSplashTheme.indexFor(seed);
      if (index == null) {
        continue;
      }
      final slotSeed = LaunchSplashTheme.seedFor(index);
      for (final brightness in Brightness.values) {
        final own = _launchColors(seed, brightness);
        final slot = _launchColors(slotSeed, brightness);
        final label = '${_hex(seed)} $brightness';
        expect(
          _channelDistance(own.mark, slot.mark),
          lessThanOrEqualTo(4),
          reason: label,
        );
        expect(
          _channelDistance(own.background, slot.background),
          lessThanOrEqualTo(4),
          reason: label,
        );
      }
    }
  });

  test('the entrypoint argument selects the slot the system splash drew', () {
    expect(
      LaunchSplashTheme.seedFromEntrypointArgs(<String>[
        launchBrandMarkEntrypointArg,
        '${launchSplashThemeArgPrefix}5',
      ]),
      LaunchSplashTheme.seedFor(5),
    );
    expect(
      LaunchSplashTheme.seedFromEntrypointArgs(<String>[
        launchBrandMarkEntrypointArg,
      ]),
      isNull,
    );
    for (final invalid in <String>[
      '-1',
      '${LaunchSplashTheme.count}',
      'x',
      '',
    ]) {
      expect(
        LaunchSplashTheme.seedFromEntrypointArgs(<String>[
          '$launchSplashThemeArgPrefix$invalid',
        ]),
        isNull,
        reason: invalid,
      );
    }
    // 原生端拼参数时用的是同一个前缀。
    expect(
      File(
        'android/app/src/main/kotlin/com/jotsy/diary/MainActivity.kt',
      ).readAsStringSync(),
      contains('"$launchSplashThemeArgPrefix"'),
    );
  });

  test('native launch splash themes match the app theme colors', () {
    final expected = <String, String>{
      _lightPath: _expectedLight(),
      _darkPath: _expectedDark(),
    };
    for (final entry in expected.entries) {
      final file = File(entry.key);
      if (_update) {
        file.writeAsStringSync(entry.value);
      }
      expect(
        file.existsSync() && file.readAsStringSync() == entry.value,
        isTrue,
        reason:
            '${entry.key} 与应用配色不一致，用 '
            '--dart-define=UPDATE_LAUNCH_SPLASH_THEMES=true 重新生成',
      );
    }
  });
}
