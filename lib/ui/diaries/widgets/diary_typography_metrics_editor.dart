import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/diary_typography.dart';
import '../../../l10n/app_localizations.dart';

/// 排版数值的显示文本：去掉末尾的 0（`1.50` → `1.5`，`16.00` → `16`）。
String formatDiaryTypographyValue(double value) {
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// 字号 / 行距 / 字间距 / 段间距 / 首行缩进五个滑块，设置页与预览页快捷面板
/// 共用。
///
/// 拖动期间只更新本地草稿（经 [onPreview] 交给需要即时预览的页面），松手时
/// 经 [onCommit] 提交；± 按钮每点一次直接提交一步，便于精确微调。提交完成
/// 前保留草稿，避免滑块在新值写回前闪回旧值。
class DiaryTypographyMetricsEditor extends StatefulWidget {
  const DiaryTypographyMetricsEditor({
    super.key,
    required this.typography,
    required this.onCommit,
    this.onPreview,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.l),
  });

  /// 已生效的排版。
  final DiaryTypography typography;
  final Future<void> Function(DiaryTypography typography) onCommit;

  /// 草稿变化（拖动中为草稿，提交后为 null）。
  final ValueChanged<DiaryTypography?>? onPreview;
  final EdgeInsetsGeometry padding;

  @override
  State<DiaryTypographyMetricsEditor> createState() =>
      _DiaryTypographyMetricsEditorState();
}

class _DiaryTypographyMetricsEditorState
    extends State<DiaryTypographyMetricsEditor> {
  DiaryTypography? _draft;

  /// 连点 ± 时多次提交交错完成：只有最后一次提交完成才清草稿，否则较早的
  /// 提交完成时会让控件短暂显示中间值。
  int _commitSerial = 0;

  DiaryTypography get _current => _draft ?? widget.typography;

  void _preview(DiaryTypography next) {
    setState(() => _draft = next);
    widget.onPreview?.call(next);
  }

  Future<void> _commit(DiaryTypography next) async {
    final serial = ++_commitSerial;
    _preview(next);
    await widget.onCommit(next);
    if (!mounted || serial != _commitSerial) {
      return;
    }
    setState(() => _draft = null);
    widget.onPreview?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = _current;
    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MetricRow(
            label: l10n.diaryTypographyFontSize,
            value: current.fontSize,
            min: DiaryTypography.minFontSize,
            max: DiaryTypography.maxFontSize,
            step: DiaryTypography.fontSizeStep,
            onChanged: (v) => _preview(current.copyWith(fontSize: v)),
            onCommit: (v) => _commit(current.copyWith(fontSize: v)),
          ),
          _MetricRow(
            label: l10n.diaryTypographyLineHeight,
            value: current.lineHeight,
            min: DiaryTypography.minLineHeight,
            max: DiaryTypography.maxLineHeight,
            step: DiaryTypography.lineHeightStep,
            onChanged: (v) => _preview(current.copyWith(lineHeight: v)),
            onCommit: (v) => _commit(current.copyWith(lineHeight: v)),
          ),
          _MetricRow(
            label: l10n.diaryTypographyLetterSpacing,
            value: current.letterSpacing,
            min: DiaryTypography.minLetterSpacing,
            max: DiaryTypography.maxLetterSpacing,
            step: DiaryTypography.letterSpacingStep,
            onChanged: (v) => _preview(current.copyWith(letterSpacing: v)),
            onCommit: (v) => _commit(current.copyWith(letterSpacing: v)),
          ),
          _MetricRow(
            label: l10n.diaryTypographyParagraphSpacing,
            value: current.paragraphSpacing,
            min: DiaryTypography.minParagraphSpacing,
            max: DiaryTypography.maxParagraphSpacing,
            step: DiaryTypography.paragraphSpacingStep,
            onChanged: (v) => _preview(current.copyWith(paragraphSpacing: v)),
            onCommit: (v) => _commit(current.copyWith(paragraphSpacing: v)),
          ),
          _MetricRow(
            label: l10n.diaryTypographyFirstLineIndent,
            value: current.firstLineIndent,
            min: DiaryTypography.minFirstLineIndent,
            max: DiaryTypography.maxFirstLineIndent,
            step: DiaryTypography.firstLineIndentStep,
            // 只有这一项的数值带单位：“2”看不出是两个字还是 2 像素。
            valueText: current.firstLineIndent == 0
                ? l10n.diaryTypographyFirstLineIndentOff
                : l10n.diaryTypographyFirstLineIndentValue(
                    current.firstLineIndent,
                    formatDiaryTypographyValue(current.firstLineIndent),
                  ),
            onChanged: (v) => _preview(current.copyWith(firstLineIndent: v)),
            onCommit: (v) => _commit(current.copyWith(firstLineIndent: v)),
          ),
        ],
      ),
    );
  }
}

/// 一项排版数值：标题与当前值一行，下方 − 滑块 + 一行（滑块占满宽度，窄屏
/// 也有足够的拖动精度）。
class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    required this.onCommit,
    this.valueText,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommit;

  /// 当前值的显示文本，缺省为去掉末尾 0 的数值。
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final valueText = this.valueText ?? formatDiaryTypographyValue(value);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                Text(
                  valueText,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: <Widget>[
              IconButton(
                tooltip: l10n.diaryTypographyDecrease(label),
                onPressed: value <= min ? null : () => onCommit(value - step),
                icon: const FaIcon(FontAwesomeIcons.minus, size: 14),
              ),
              Expanded(
                child: Semantics(
                  label: label,
                  child: Slider(
                    value: value.clamp(min, max).toDouble(),
                    min: min,
                    max: max,
                    divisions: ((max - min) / step).round(),
                    onChanged: onChanged,
                    onChangeEnd: onCommit,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.diaryTypographyIncrease(label),
                onPressed: value >= max ? null : () => onCommit(value + step),
                icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
