import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import 'expressive_menu_anchor.dart';

/// [ExpressiveMenuAnchor] 里的一项（移植自 phase 的 AppMenuItemButton）。
///
/// RawMenuAnchor 不会替条目关闭菜单，所以这里关掉 [MenuItemButton] 的
/// closeOnActivate，改为先经锚点关闭菜单、再执行 [onPressed]；收起途中的
/// 点按直接忽略，动作不会被执行两次。
///
/// 默认样式由条目自己给出（不在全局主题里加 menuButtonTheme，免得改动其他
/// 用到 MenuItemButton 的控件）：最小高 48、左右内边距 16、图标与文字间距 12；
/// 文字 bodyMedium + onSurface，前置图标 16px + onSurfaceVariant；静止圆角 20、
/// 按下收紧到 12（fast，减少动画时无过渡）。[destructive] 把文字与图标换成
/// error 色。禁用态沿用 Material 默认的禁用色。[style] 中非空的字段覆盖默认值。
class ExpressiveMenuItem extends StatelessWidget {
  const ExpressiveMenuItem({
    super.key,
    required this.onPressed,
    required this.child,
    this.leadingIcon,
    this.trailingIcon,
    this.destructive = false,
    this.style,
  });

  /// 为 null 时条目禁用。
  final VoidCallback? onPressed;
  final Widget child;

  /// 前置图标，通常是不带尺寸与颜色的 `FaIcon`，由条目统一为 16px。
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  /// 危险操作（如删除）：文字与图标使用 `colorScheme.error`。
  final bool destructive;
  final ButtonStyle? style;

  static const double minHeight = 48;
  static const double horizontalPadding = 16;
  static const double iconSize = 16;
  static const double restingRadius = 20;
  static const double pressedRadius = 12;

  ButtonStyle _defaultStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // 只给可用状态指定颜色；禁用态返回 null，落回 MenuItemButton 的默认禁用色。
    WidgetStateProperty<Color?> enabledColor(Color color) =>
        WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.disabled) ? null : color,
        );
    return ButtonStyle(
      foregroundColor: enabledColor(
        destructive ? colors.error : colors.onSurface,
      ),
      iconColor: enabledColor(
        destructive ? colors.error : colors.onSurfaceVariant,
      ),
      iconSize: const WidgetStatePropertyAll<double>(iconSize),
      textStyle: WidgetStatePropertyAll<TextStyle?>(theme.textTheme.bodyMedium),
      minimumSize: const WidgetStatePropertyAll<Size>(Size(0, minHeight)),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: horizontalPadding),
      ),
      // 固定标准密度：MenuItemButton 按密度推算图标与文字间距，标准密度下为 12。
      visualDensity: VisualDensity.standard,
      shape: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            states.contains(WidgetState.pressed) &&
                    !states.contains(WidgetState.disabled)
                ? pressedRadius
                : restingRadius,
          ),
        ),
      ),
      // Material 按 animationDuration 补间形状，减少动画时直接切换。
      animationDuration: ExpressiveMotion.duration(
        context,
        ExpressiveMotion.fast,
      ),
    );
  }

  void _activate(BuildContext context) {
    if (!context.mounted) return;
    final anchor = ExpressiveMenuAnchorState.maybeOf(context);
    if (anchor != null) {
      if (!anchor.interactive) return;
      anchor.close();
    }
    // 先让焦点回到触发控件，再执行动作：动作若打开对话框或新页面，
    // 关闭后焦点能正确落回入口。
    FocusManager.instance.applyFocusChangesIfNeeded();
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final defaults = _defaultStyle(context);
    return MenuItemButton(
      closeOnActivate: false,
      overflowAxis: Axis.vertical,
      style: style?.merge(defaults) ?? defaults,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      onPressed: onPressed == null ? null : () => _activate(context),
      child: child,
    );
  }
}
