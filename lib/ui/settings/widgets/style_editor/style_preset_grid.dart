import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../widgets/expressive_state_blend.dart';

/// 一套内置预设在网格里的展示：图标、名称与一句说明。
@immutable
class StylePresetOption<T> {
  const StylePresetOption({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
  });

  final T id;
  final FaIconData icon;
  final String name;
  final String description;
}

/// 内置预设的两列网格；每行两格等高（IntrinsicHeight，只有几行，开销可
/// 忽略）。选中格经 [ExpressiveStateBlend] 过渡到 `secondaryContainer`。
class StylePresetGrid<T> extends StatelessWidget {
  const StylePresetGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<StylePresetOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var row = 0; row < options.length; row += 2) ...<Widget>[
          if (row > 0) const SizedBox(height: AppSpacing.s),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var col = 0; col < 2; col++) ...<Widget>[
                  if (col > 0) const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: row + col < options.length
                        ? _PresetTile<T>(
                            option: options[row + col],
                            selected: selected == options[row + col].id,
                            onTap: () => onSelected(options[row + col].id),
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

class _PresetTile<T> extends StatelessWidget {
  const _PresetTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final StylePresetOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 玻璃时未选中为玻璃底色 + 玻璃描边（随选中淡出），选中色不变；经典时
    // 原样（side 为 none 与只给 borderRadius 的形状一致）。
    final glassField = AppGlassField.of(context);
    final restingSide = glassField?.border ?? BorderSide.none;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: ExpressiveStateBlend(
        active: selected,
        builder: (BuildContext context, double t, Widget? child) {
          final background = Color.lerp(
            glassField?.fill ??
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide.lerp(restingSide, BorderSide.none, t),
            ),
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
                        FaIcon(option.icon, size: 16, color: foreground),
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
                      option.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.description,
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
