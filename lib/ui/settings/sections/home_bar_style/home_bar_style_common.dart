import 'package:flutter/material.dart';

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
