import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style_presets.dart';
import '../../../widgets/expressive_state_blend.dart';
import 'diary_card_style_labels.dart';

/// 内置风格的两列网格；每行两格等高（IntrinsicHeight，只有四行，开销可忽略）。
class DiaryCardPresetGrid extends StatelessWidget {
  const DiaryCardPresetGrid({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final DiaryCardPresetId? selected;
  final ValueChanged<DiaryCardPresetId> onSelected;

  @override
  Widget build(BuildContext context) {
    const ids = DiaryCardPresetId.values;
    return Column(
      children: <Widget>[
        for (var row = 0; row < ids.length; row += 2) ...<Widget>[
          if (row > 0) const SizedBox(height: AppSpacing.s),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var col = 0; col < 2; col++) ...<Widget>[
                  if (col > 0) const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: row + col < ids.length
                        ? _PresetTile(
                            id: ids[row + col],
                            selected: selected == ids[row + col],
                            onTap: () => onSelected(ids[row + col]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final DiaryCardPresetId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: ExpressiveStateBlend(
        active: selected,
        builder: (BuildContext context, double t, Widget? child) {
          final background = Color.lerp(
            scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            scheme.secondaryContainer,
            t,
          );
          final foreground = Color.lerp(
            scheme.onSurfaceVariant,
            scheme.onSecondaryContainer,
            t,
          );
          return Material(
            color: background,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        FaIcon(
                          diaryCardPresetIcon(id),
                          size: 16,
                          color: foreground,
                        ),
                        const Spacer(),
                        if (selected)
                          FaIcon(
                            FontAwesomeIcons.solidCircleCheck,
                            size: 16,
                            color: scheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      diaryCardPresetName(l10n, id),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      diaryCardPresetDescription(l10n, id),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
