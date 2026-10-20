import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
/// 文字 bodyMedium + onSurface，前置图标 16px + primary（菜单底色是半透明玻璃，
/// 灰色图标显得发闷，用主色点出每一项）；按下 / 悬停 / 聚焦的叠色也取 primary；
/// 静止圆角 20、按下收紧到 12（fast，减少动画时无过渡）。[destructive] 把文字、
/// 图标与叠色换成 error 色。[selected] 为 true 时铺 primaryContainer 底、
/// 文字加粗、行尾补一个对勾，圆角放到 24（胶囊）。禁用态沿用 Material 默认的
/// 禁用色。[style] 中非空的字段覆盖默认值。
class ExpressiveMenuItem extends StatelessWidget {
  const ExpressiveMenuItem({
    super.key,
    required this.onPressed,
    required this.child,
    this.leadingIcon,
    this.trailingIcon,
    this.destructive = false,
    this.selected,
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

  /// 单选 / 勾选菜单里这一项是否为当前值；null 表示普通动作项。
  ///
  /// 非 null 时同时写进语义（读屏读出“已选中”）；为 true 且没有给
  /// [trailingIcon] 时行尾显示对勾。
  final bool? selected;
  final ButtonStyle? style;

  static const double minHeight = 48;
  static const double horizontalPadding = 16;
  static const double iconSize = 16;
  static const double restingRadius = 20;
  static const double pressedRadius = 12;
  static const double selectedRadius = 24;
  static const double checkSize = 14;

  ButtonStyle _defaultStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // 只给可用状态指定颜色；禁用态返回 null，落回 MenuItemButton 的默认禁用色。
    WidgetStateProperty<Color?> enabledColor(Color color) =>
        WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.disabled) ? null : color,
        );
    final isSelected = selected ?? false;
    final accent = destructive ? colors.error : colors.primary;
    return ButtonStyle(
      backgroundColor: WidgetStatePropertyAll<Color?>(
        isSelected ? colors.primaryContainer : null,
      ),
      foregroundColor: enabledColor(
        destructive
            ? colors.error
            : isSelected
            ? colors.onPrimaryContainer
            : colors.onSurface,
      ),
      iconColor: enabledColor(isSelected ? colors.onPrimaryContainer : accent),
      // 叠色随强调色走：选中的按下叠色取 onPrimaryContainer，在主色容器底上
      // 才看得出来。
      overlayColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        final tone = isSelected ? colors.onPrimaryContainer : accent;
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.focused)) {
          return tone.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return tone.withValues(alpha: 0.08);
        }
        return null;
      }),
      iconSize: const WidgetStatePropertyAll<double>(iconSize),
      textStyle: WidgetStatePropertyAll<TextStyle?>(
        isSelected
            ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
            : theme.textTheme.bodyMedium,
      ),
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
                : isSelected
                ? selectedRadius
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
    final isSelected = selected;
    return MenuItemButton(
      closeOnActivate: false,
      overflowAxis: Axis.vertical,
      style: style?.merge(defaults) ?? defaults,
      leadingIcon: leadingIcon,
      trailingIcon:
          trailingIcon ??
          (isSelected ?? false
              ? const ExcludeSemantics(
                  child: FaIcon(FontAwesomeIcons.check, size: checkSize),
                )
              : null),
      onPressed: onPressed == null ? null : () => _activate(context),
      // 选中状态标在文字上：MenuItemButton 外层是 MergeSemantics，包在它外面的
      // Semantics 会落到父节点上，只有放在里面才并进条目自己的语义节点。
      child: isSelected == null
          ? child
          : Semantics(selected: isSelected, child: child),
    );
  }
}
