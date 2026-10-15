import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/theme/app_spacing.dart';
import 'expressive_icon_swap.dart';
import 'expressive_state_blend.dart';

/// 面板中的单选项：单选圆点 + 文案，可带一行说明。
///
/// 选中项只换容器色、字重与单选图标颜色，文字保持 onSurface：部分配色下
/// onSecondaryContainer 偏浅，会让选中项看起来比其他项更弱（与地址层级菜单
/// 一致）。面板保持打开，选中态变化会被看到：容器色与图标颜色经
/// [ExpressiveStateBlend] 补间（ListTile 的 tileColor 不做隐式动画），单选图标
/// 缩放淡入切换。容器色经 ListTile 的 tileColor（Ink 绘制）给出，外层不包
/// 不透明容器，避免盖住水波纹；`selected` 同时为读屏暴露选中态。
///
/// [destructive] 标记会永久改写数据的选项：标题常驻 error 色，选中时底色换成
/// errorContainer、圆点换成 error 色，选到的那一刻就能看出风险。
class ExpressiveChoiceTile extends StatelessWidget {
  const ExpressiveChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
    this.destructive = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 选项后果的简短说明，显示在标题下方。
  final String? description;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = destructive ? colorScheme.error : colorScheme.primary;
    final container = destructive
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final description = this.description;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ExpressiveStateBlend(
        active: selected,
        builder: (BuildContext context, double t, Widget? child) {
          final tileColor = container.withValues(alpha: t);
          return ListTile(
            selected: selected,
            tileColor: tileColor,
            selectedTileColor: tileColor,
            dense: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            minLeadingWidth: 24,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
            ),
            // 说明可能折成多行，圆点对齐标题行而不是整块的垂直中线。
            titleAlignment: description == null
                ? null
                : ListTileTitleAlignment.top,
            onTap: onTap,
            leading: ExpressiveIconSwap(
              switchKey: selected,
              child: FaIcon(
                selected ? FontAwesomeIcons.circleDot : FontAwesomeIcons.circle,
                size: 16,
                color: Color.lerp(colorScheme.onSurfaceVariant, accent, t),
              ),
            ),
            title: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: destructive ? colorScheme.error : colorScheme.onSurface,
              ),
            ),
            // 危险项选中后底色是 errorContainer，说明随之过渡到配套的
            // onErrorContainer，暗色下灰字压在深红底上会发闷。
            subtitle: description == null
                ? null
                : Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: destructive
                          ? Color.lerp(
                              colorScheme.onSurfaceVariant,
                              colorScheme.onErrorContainer,
                              t,
                            )
                          : colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
          );
        },
      ),
    );
  }
}
