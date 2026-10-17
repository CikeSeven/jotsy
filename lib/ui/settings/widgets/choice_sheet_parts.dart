import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';

/// 选择面板（导入来源、备份位置）共用的分组标题：主色图标 + 粗体标题。
class ChoiceSheetSectionHeader extends StatelessWidget {
  const ChoiceSheetSectionHeader({
    super.key,
    required this.icon,
    required this.label,
  });

  final FaIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.s,
      ),
      child: Semantics(
        header: true,
        child: Row(
          children: <Widget>[
            FaIcon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分组标题下的说明文字。
class ChoiceSheetSectionHint extends StatelessWidget {
  const ChoiceSheetSectionHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        AppSpacing.xs,
        AppSpacing.m,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
    );
  }
}

/// 两列等宽的紧凑选项按钮（`secondaryContainer` 底色，16dp 圆角），奇数项
/// 时最后一个占半宽靠左；名称过长时缩小字号而不折行。[iconOf] 为空时只显示
/// 名称（分组标题已有图标）。
class ChoiceSheetCompactGrid<T> extends StatelessWidget {
  const ChoiceSheetCompactGrid({
    super.key,
    required this.items,
    required this.nameOf,
    required this.onPick,
    this.iconOf,
  });

  final List<T> items;
  final String Function(T item) nameOf;
  final FaIconData Function(T item)? iconOf;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = (constraints.maxWidth - AppSpacing.s) / 2;
        return Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: <Widget>[
            for (final item in items)
              SizedBox(
                width: width,
                child: Material(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onPick(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.m,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (iconOf != null) ...<Widget>[
                              FaIcon(
                                iconOf!(item),
                                size: 14,
                                color: colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: AppSpacing.s),
                            ],
                            Text(
                              nameOf(item),
                              maxLines: 1,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
