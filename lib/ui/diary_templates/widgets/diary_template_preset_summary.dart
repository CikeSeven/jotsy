import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../models/diary_template.dart';
import '../viewmodels/diary_template_labels.dart';

/// 模板套用后除标题、正文外还会带上的东西：`# 标签`、心情、精力与时间
/// 胶囊，排成一行可换行的微胶囊。没有预设时不占位。
class DiaryTemplatePresetSummary extends StatelessWidget {
  const DiaryTemplatePresetSummary({super.key, required this.template});

  final DiaryTemplate template;

  @override
  Widget build(BuildContext context) {
    if (!template.hasPresets) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: <Widget>[
        for (final tag in template.tags)
          _PresetChip(label: '# ${tag.name}', color: Color(tag.color)),
        if (template.mood case final mood?)
          _PresetChip(label: mood, color: colorScheme.secondary),
        if (template.energy case final energy?)
          _PresetChip(
            label: l10n.diaryTemplatePresetEnergy(energy),
            color: colorScheme.secondary,
          ),
        if (template.capsule case final capsule?)
          _PresetChip(
            label: l10n.diaryTemplatePresetCapsule(
              diaryTemplateCapsuleLabel(l10n, capsule),
            ),
            color: colorScheme.tertiary,
          ),
      ],
    );
  }
}

/// 微胶囊：颜色 12% 透明度底 + 原色字（DESIGN §5.2 的标签胶囊）。
class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 用户自定义的标签色在暗色主题里可能太暗，文字改用 onSurface 保证可读。
    final textColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : color;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
