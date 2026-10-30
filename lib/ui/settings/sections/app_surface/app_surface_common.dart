import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/style_library/style_json.dart';
import '../../widgets/settings_option_tiles.dart';

/// “背景与材质”各分组共用的数值滑块行：拖动中经 [onPreview] 只改草稿
/// （预览即时重绘、不写盘），松手经 [onCommit] 写入。
///
/// [enabled] 为 false 时（如参数跟随来源）滑块停用，只显示 [value]。
///
/// 取值先按 [range] 的步进规整（消除 0.35000001 这类浮点尾数，设置才能与
/// 默认值按 `==` 相等、编码保持稀疏），再交给回调。
Widget appSurfaceSlider({
  required String title,
  required StyleRange range,
  required double value,
  required String Function(double value) valueLabel,
  required ValueChanged<double> onPreview,
  required ValueChanged<double> onCommit,
  bool nested = false,
  bool enabled = true,
}) {
  double normalize(double raw) {
    final steps = ((raw - range.min) / range.step).round();
    final snapped = range.min + steps * range.step;
    // 再按百分位取整：0.05 的步进累乘后会带上浮点尾数。
    return range.clamp((snapped * 100).round() / 100);
  }

  return SettingsSliderTile(
    title: title,
    nested: nested,
    value: value,
    min: range.min,
    max: range.max,
    divisions: range.divisions,
    valueLabel: valueLabel,
    onChanged: enabled ? (double v) => onPreview(normalize(v)) : null,
    onChangeEnd: enabled ? (double v) => onCommit(normalize(v)) : null,
  );
}

/// 0..1 的比例显示为百分数（沿用卡片样式页的“{value}%”文案）。
String appSurfacePercentLabel(AppLocalizations l10n, double value) =>
    l10n.diaryCardStyleValuePercent('${(value * 100).round()}');
