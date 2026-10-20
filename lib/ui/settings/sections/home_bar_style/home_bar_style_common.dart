import 'package:flutter/material.dart';

import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../diaries/models/style_library/style_json.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/settings_option_tiles.dart';

/// 导航栏样式各标签页共用的数值滑块行：拖动中经 `previewWith` 只改草稿
/// （预览即时重绘、不写盘），松手经 `commitWith` 写入。
///
/// [snap] 把滑块给出的值规整到步进（消除 0.65000001 这类浮点尾数，样式
/// 才能与预设按 `==` 相等）；缺省时取整（多数尺寸的步进是整数）。
Widget homeBarSlider({
  required HomeBarStyleEditorController controller,
  required String title,
  required StyleRange range,
  required double value,
  required String Function(double value) valueLabel,
  required HomeBarStyle Function(HomeBarStyle style, double value) apply,
  double Function(double value)? snap,
  bool nested = false,
}) {
  double normalize(double raw) =>
      snap == null ? raw.roundToDouble() : snap(raw);
  return SettingsSliderTile(
    title: title,
    nested: nested,
    value: value,
    min: range.min,
    max: range.max,
    divisions: range.divisions,
    valueLabel: valueLabel,
    onChanged: (double v) =>
        controller.previewWith((style) => apply(style, normalize(v))),
    onChangeEnd: (double v) =>
        controller.commitWith((style) => apply(style, normalize(v))),
  );
}

/// 浅色主题的配色：自定义颜色（玻璃底色、描边）以浅色值为主、深色由它推导，
/// 第一次切到自定义时的起始颜色因此取浅色主题下的值——深色界面里也一样，
/// 否则存进去的“浅色值”其实是深色下的颜色。
ColorScheme homeBarLightScheme(
  BuildContext context,
  HomeBarStyleEditorController controller,
) {
  final theme = Theme.of(context);
  if (theme.brightness == Brightness.light) {
    return theme.colorScheme;
  }
  return SeededThemeCache.of(
    Color(controller.settingsService.themeSeedColorValue),
    Brightness.light,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
  ).colorScheme;
}

/// 去掉透明度的 ARGB：自定义颜色一律存为不透明色。
int homeBarOpaqueArgb(Color color) =>
    0xFF000000 | (color.toARGB32() & 0xFFFFFF);
