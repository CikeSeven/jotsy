import 'package:flutter/material.dart';

// 设置分组卡片里的通用行：开关、行内滑块与“标题 + 选择器”。与设置页
// 既有的 ListTile 同一字阶与内边距（标题取 listTileTheme，左右 16）。

/// 开关行。
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.nested = false,
  });

  /// 从属开关（[nested]）的内容起点：比平级行多缩进一级。分组里它上方的
  /// 分割线也从这里开始（见 `SettingsCardGroupDivider.indent`）。
  static const double nestedIndent = 40;

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// 是否为上一行的从属开关（如功能管理里日历下方的纪念日）：内容缩进一级、
  /// 标题字号与字重轻一档，一眼看出它挂在上一行之下，而不是并列的一项。
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return SwitchListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: nested ? nestedIndent : 16,
        end: 16,
        top: 2,
        bottom: 2,
      ),
      value: value,
      // 与 listTileTheme 的标题样式合并，只改字号与字重。
      title: Text(
        title,
        style: nested
            ? const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)
            : null,
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      onChanged: onChanged,
    );
  }
}

/// 行内滑块：标题 + 当前值 + 滑块。
///
/// 拖动中经 [onChanged] 即时预览，松手经 [onChangeEnd] 提交；取值按
/// [divisions] 吸附到步进。读屏朗读 [valueLabel] 给出的文本而不是原始小数。
class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    required this.onChangeEnd,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) valueLabel;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    final clamped = value.clamp(min, max).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style:
                      theme.listTileTheme.titleTextStyle ??
                      theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                valueLabel(clamped),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: theme.listTileTheme.subtitleTextStyle,
              ),
            ),
          // 分段数不同的滑块有的显示刻度点、有的过密而不显示，同页并排时
          // 显得杂乱；统一不画刻度，数值看标题右侧。
          SliderTheme(
            data: SliderTheme.of(
              context,
            ).copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
            child: Slider(
              value: clamped,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
              semanticFormatterCallback: valueLabel,
            ),
          ),
        ],
      ),
    );
  }
}

/// 标题（可带说明）+ 下方的选择器（连接按钮组、图标选择行等）。
class SettingsChoiceTile extends StatelessWidget {
  const SettingsChoiceTile({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style:
                theme.listTileTheme.titleTextStyle ??
                theme.textTheme.titleMedium,
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: theme.listTileTheme.subtitleTextStyle,
              ),
            ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
