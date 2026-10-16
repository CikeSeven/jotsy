import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../diaries/viewmodels/diary_card_colors.dart';
import '../sections/diary_card_style/diary_card_style_labels.dart';
import 'style_editor/style_color_dialog.dart';
import 'settings_option_tiles.dart';

/// 卡片样式里一个颜色位的设置行：来源选择（默认 / 主题三色 / 心情 / 首个
/// 标签 / 自定义）、自定义颜色的浅深两态，以及可选的浓度滑块。
///
/// 选择“自定义”时弹出取色对话框，取消则保持原来源。浓度拖动经
/// [onPreview] 即时预览、松手经 [onCommit] 提交；其余改动直接提交。
class DiaryCardColorTile extends StatelessWidget {
  const DiaryCardColorTile({
    super.key,
    required this.title,
    required this.spec,
    required this.role,
    required this.onPreview,
    required this.onCommit,
    this.subtitle,
    this.sources = DiaryCardColorSource.values,
    this.showStrength = true,
    this.strengthAppliesToTheme = false,
  });

  final String title;
  final String? subtitle;
  final DiaryCardColorSpec spec;
  final DiaryCardColorRole role;
  final ValueChanged<DiaryCardColorSpec> onPreview;
  final ValueChanged<DiaryCardColorSpec> onCommit;
  final List<DiaryCardColorSource> sources;
  final bool showStrength;

  /// 默认来源也读浓度（阴影与强调条的颜色本身带不透明度），此时默认来源
  /// 下同样显示浓度滑块。
  final bool strengthAppliesToTheme;

  Color? _sourceColor(ColorScheme scheme, DiaryCardColorSource source) =>
      switch (source) {
        DiaryCardColorSource.primary => scheme.primary,
        DiaryCardColorSource.secondary => scheme.secondary,
        DiaryCardColorSource.tertiary => scheme.tertiary,
        DiaryCardColorSource.custom => _customColor(scheme),
        _ => null,
      };

  Color? _customColor(ColorScheme scheme) {
    final light = spec.light;
    if (light == null) {
      return null;
    }
    if (scheme.brightness == Brightness.light) {
      return Color(light);
    }
    final dark = spec.dark;
    return dark != null
        ? Color(dark)
        : DiaryCardColors.deriveDark(Color(light), role);
  }

  Future<void> _editCustom(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final result = await showStyleColorDialog(
      context,
      title: title,
      light:
          spec.light ??
          (_sourceColor(scheme, DiaryCardColorSource.primary)!).toARGB32(),
      dark: spec.dark,
      role: role,
    );
    if (result == null) {
      return;
    }
    onCommit(
      DiaryCardColorSpec(
        source: DiaryCardColorSource.custom,
        light: result.light,
        dark: result.dark,
        strength: spec.strength,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = this.subtitle;
    final hint = switch (spec.source) {
      DiaryCardColorSource.mood => l10n.diaryCardStyleSourceMoodHint,
      DiaryCardColorSource.firstTag => l10n.diaryCardStyleSourceTagHint,
      _ => null,
    };

    Widget avatar(DiaryCardColorSource source) {
      final color = _sourceColor(scheme, source);
      if (color != null) {
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        );
      }
      return FaIcon(switch (source) {
        DiaryCardColorSource.mood => FontAwesomeIcons.faceSmile,
        DiaryCardColorSource.firstTag => FontAwesomeIcons.tag,
        DiaryCardColorSource.custom => FontAwesomeIcons.eyeDropper,
        _ => FontAwesomeIcons.circleHalfStroke,
      }, size: 12);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final source in sources)
                    ChoiceChip(
                      avatar: avatar(source),
                      label: Text(diaryCardColorSourceLabel(l10n, source)),
                      selected: spec.source == source,
                      showCheckmark: false,
                      onSelected: (_) {
                        if (source == DiaryCardColorSource.custom) {
                          _editCustom(context);
                        } else if (source != spec.source) {
                          onCommit(spec.copyWith(source: source));
                        }
                      },
                    ),
                ],
              ),
              if (spec.source == DiaryCardColorSource.custom &&
                  spec.light != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => _editCustom(context),
                      icon: const FaIcon(FontAwesomeIcons.palette, size: 14),
                      label: Text(l10n.styleEditorEditColor),
                    ),
                  ),
                ),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (showStrength && (strengthAppliesToTheme || !spec.isThemed))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SettingsSliderTile(
              title: l10n.diaryCardStyleStrength,
              value: spec.strength,
              min: DiaryCardStyleLimits.strength.min,
              max: DiaryCardStyleLimits.strength.max,
              divisions: DiaryCardStyleLimits.strength.divisions,
              valueLabel: (double value) => diaryCardPercentLabel(l10n, value),
              onChanged: (double value) =>
                  onPreview(spec.copyWith(strength: value)),
              onChangeEnd: (double value) =>
                  onCommit(spec.copyWith(strength: value)),
            ),
          ),
      ],
    );
  }
}
