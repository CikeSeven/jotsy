import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_state_blend.dart';

/// 搜索页输入框下方那一行的胶囊：条件（日记本、标签）与筛选（标签、时间、
/// 心情、媒体、天气、地点、含归档）共用一种外观（DESIGN.md §5.33）。
///
/// - 未生效：控件底色（玻璃时为 [AppGlassField] 的填充与描边）+ 次要色文字，
///   可选行尾 ▾（[showCaret]，点按打开选择器）；
/// - 已生效：`secondaryContainer` 实底。行尾 ×（[onRemove]）单独响应，点胶囊
///   其余部分仍是 [onTap]（重新打开选择器）。两态之间经
///   [ExpressiveStateBlend] 补间。
///
/// 36 高、12 圆角；名称最宽 [maxLabelWidth]，超出省略，1.3 倍字号下高度随
/// 文字长高、不截字。
class DiarySearchChip extends StatelessWidget {
  const DiarySearchChip({
    super.key,
    required this.label,
    required this.active,
    this.leading,
    this.onTap,
    this.onRemove,
    this.removeLabel,
    this.showCaret = false,
  });

  static const double height = 36;
  static const double maxLabelWidth = 168;

  final String label;
  final bool active;

  /// 名称前的小图标（12px）。
  final Widget? leading;
  final VoidCallback? onTap;

  /// 行尾 × ；null 时不显示。
  final VoidCallback? onRemove;

  /// × 的读屏标签（如“移除标签 旅行”）。
  final String? removeLabel;
  final bool showCaret;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glassField = AppGlassField.of(context);
    final idleFill = glassField?.fill ?? scheme.surfaceContainerHigh;
    final idleBorder =
        glassField?.border?.color ??
        scheme.outlineVariant.withValues(alpha: 0.6);
    final activeFill = scheme.secondaryContainer;
    final activeForeground = scheme.onSecondaryContainer;
    return ExpressiveStateBlend(
      active: active,
      builder: (BuildContext context, double t, Widget? _) {
        final foreground = Color.lerp(
          scheme.onSurfaceVariant,
          activeForeground,
          t,
        )!;
        // 已生效时略加粗；字重不能补间，过半即切换（颜色仍是补间的）。
        final labelStyle = theme.textTheme.labelLarge?.copyWith(
          color: Color.lerp(scheme.onSurface, activeForeground, t),
          fontWeight: t >= 0.5 ? FontWeight.w600 : FontWeight.w500,
        );
        return Material(
          color: Color.lerp(idleFill, activeFill, t),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Color.lerp(idleBorder, activeFill, t)!,
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: height),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: 12,
                  end: onRemove != null ? 2 : (showCaret ? 10 : 12),
                ),
                child: IconTheme.merge(
                  data: IconThemeData(color: foreground, size: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (leading case final leading?) ...<Widget>[
                        leading,
                        const SizedBox(width: 6),
                      ],
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: maxLabelWidth,
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                      ),
                      if (onRemove case final remove?)
                        _RemoveButton(
                          color: foreground,
                          label: removeLabel,
                          onTap: remove,
                        )
                      else if (showCaret) ...<Widget>[
                        const SizedBox(width: 6),
                        FaIcon(
                          FontAwesomeIcons.angleDown,
                          size: 10,
                          color: foreground,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 行尾 ×：32dp 见方的点击区（不撑高 36 的胶囊），带读屏标签。
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({
    required this.color,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 不排除子节点语义：点按动作来自 InkResponse，排除后读屏点不动它。
    // container：胶囊本身不可点（标签条件）时，这里仍是独立的一个按钮节点，
    // 不会和胶囊名称并成一个。
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 16,
        child: SizedBox.square(
          dimension: 32,
          child: Center(
            child: FaIcon(FontAwesomeIcons.xmark, size: 10, color: color),
          ),
        ),
      ),
    );
  }
}
