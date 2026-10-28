import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/theme/app_spacing.dart';
import '../app_surface/widgets/app_glass_field.dart';
import 'expressive_state_blend.dart';

/// 图标选择行中的一项。
class ExpressiveIconChoice<T> {
  const ExpressiveIconChoice({
    required this.value,
    required this.icon,
    required this.label,
  });

  final T value;
  final FaIconData icon;
  final String label;
}

/// 多个选项并排的图标单选器（图标 + 短标签的圆角色块）。
///
/// 选项较多（四个以上）时比连接按钮组更省宽度：一行放下，比逐个带说明的
/// 单选项省出大半屏高度。超过 [maxPerRow] 个时折成多行，末行用空位补齐，
/// 每个色块宽度一致。选中项换 secondaryContainer 底并经
/// [ExpressiveStateBlend] 补间。未选中的底色与描边按 [AppGlassField] 取色
/// （与按钮组未选中的段落同一口径），选中色不变。
class ExpressiveIconChoiceRow<T> extends StatelessWidget {
  const ExpressiveIconChoiceRow({
    super.key,
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.maxPerRow = 5,
  });

  final List<ExpressiveIconChoice<T>> choices;
  final T selected;
  final ValueChanged<T>? onSelected;
  final int maxPerRow;

  @override
  Widget build(BuildContext context) {
    final perRow = choices.length <= maxPerRow
        ? choices.length
        : (choices.length / (choices.length / maxPerRow).ceil()).ceil();
    final rows = <Widget>[];
    for (var start = 0; start < choices.length; start += perRow) {
      final rowChoices = choices.skip(start).take(perRow).toList();
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: AppSpacing.xs));
      }
      rows.add(
        Row(
          children: <Widget>[
            for (var i = 0; i < perRow; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: i < rowChoices.length
                    ? _IconChoiceSwatch(
                        icon: rowChoices[i].icon,
                        label: rowChoices[i].label,
                        selected: rowChoices[i].value == selected,
                        onTap: onSelected == null
                            ? null
                            : () => onSelected!(rowChoices[i].value),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    if (rows.length == 1) {
      return rows.single;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _IconChoiceSwatch extends StatelessWidget {
  const _IconChoiceSwatch({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final glassField = AppGlassField.of(context);
    final restingSide = glassField?.border;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: ExpressiveStateBlend(
        active: selected,
        builder: (BuildContext context, double t, Widget? child) {
          final background = Color.lerp(
            glassField?.fill ??
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            colorScheme.secondaryContainer,
            t,
          );
          final foreground = Color.lerp(
            colorScheme.onSurfaceVariant,
            colorScheme.onSecondaryContainer,
            t,
          );
          // 描边只属于未选中态，随选中补间淡出。经典时 side 为 none，
          // 与原来的 borderRadius 写法画出的形状一致。
          return Material(
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: restingSide == null
                  ? BorderSide.none
                  : BorderSide.lerp(restingSide, BorderSide.none, t),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.m,
                  horizontal: AppSpacing.xs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FaIcon(icon, size: 18, color: foreground),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
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
