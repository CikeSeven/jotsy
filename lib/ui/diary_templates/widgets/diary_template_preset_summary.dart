import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../settings/providers/app_features_provider.dart';
import '../models/diary_template.dart';
import '../viewmodels/diary_template_labels.dart';

/// 模板套用后除标题、正文外还会带上的东西：`# 标签`、心情、精力与时间
/// 胶囊，排成一行可换行的微胶囊。没有预设时不占位（连同 [padding]）。
///
/// 时间胶囊功能关闭时隐藏入口，数据保留：胶囊预设套用时不生效（见
/// `DiaryTemplateApplyController`），这里也不显示；只有胶囊预设时整块不占位。
class DiaryTemplatePresetSummary extends ConsumerWidget {
  const DiaryTemplatePresetSummary({
    super.key,
    required this.template,
    this.padding = EdgeInsets.zero,
  });

  final DiaryTemplate template;

  /// 有内容时围在外面的留白（与上方内容的间距由这里给，没预设时一并省去）。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capsulesEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.timeCapsules),
    );
    final shown = capsulesEnabled
        ? template
        : template.copyWith(capsule: () => null);
    if (!shown.hasPresets) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: AppSpacing.s,
        runSpacing: AppSpacing.s,
        children: <Widget>[
          for (final tag in shown.tags)
            _PresetChip(label: '# ${tag.name}', color: Color(tag.color)),
          if (shown.mood case final mood?)
            _PresetChip(label: mood, color: colorScheme.secondary),
          if (shown.energy case final energy?)
            _PresetChip(
              label: l10n.diaryTemplatePresetEnergy(energy),
              color: colorScheme.secondary,
            ),
          if (shown.capsule case final capsule?)
            _PresetChip(
              label: l10n.diaryTemplatePresetCapsule(
                diaryTemplateCapsuleLabel(l10n, capsule),
              ),
              color: colorScheme.tertiary,
            ),
        ],
      ),
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
