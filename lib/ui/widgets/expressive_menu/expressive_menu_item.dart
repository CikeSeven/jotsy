import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'expressive_menu_anchor.dart';
import 'expressive_menu_row.dart';

/// [ExpressiveMenuAnchor] 里的一项（移植自 NexioSchedule 的菜单项）。
///
/// 外观（尺寸见 [ExpressiveMenuRowMetrics]）：每行是左右缩进 6 的胶囊（高亮胶囊
/// 16 圆角，由面板统一画，见 [ExpressiveMenuRowInk]），胶囊里左右 12、上下 9；
/// 前置图标在 22 × 22 的格子里（图标 16px、与文字同色）、到文字 10；文字 14.5
/// 字重 500（`onSurface`），可带一行说明 [summary]（`bodyMedium`，
/// `onSurfaceVariant`）；图标 + 文字那段最宽 216。动作项（[selected] 为 null）
/// 行尾不留空；选择项行尾始终留出 10 + 18 的对勾格，当前项画主色对勾、文字与说明也换成主色（文字不会因选中而左右挪动）；
/// 给了 [trailingIcon] 时由它占据这一格。[destructive] 文字与图标为 `error`；
/// 禁用时 38% 的 `onSurface`。
///
/// 点按：RawMenuAnchor 不会替条目关闭菜单，这里先经锚点关闭（收起途中的
/// 点按直接忽略，动作不会执行两次）再执行 [onPressed]。[closeOnActivate] 为
/// false 时只执行动作、菜单保持打开（要连着调的单选项）。不在锚点里（如
/// 桌面文字右键菜单）时直接执行。
class ExpressiveMenuItem extends StatelessWidget {
  const ExpressiveMenuItem({
    super.key,
    required this.onPressed,
    required this.child,
    this.leadingIcon,
    this.trailingIcon,
    this.summary,
    this.destructive = false,
    this.selected,
    this.closeOnActivate = true,
    this.highlighted = false,
    this.focusNode,
  });

  /// 为 null 时条目禁用。
  final VoidCallback? onPressed;

  /// 条目文字，通常是 `Text`。
  final Widget child;

  /// 前置图标，通常是不带尺寸与颜色的 `FaIcon`，由条目统一尺寸与颜色。
  final Widget? leadingIcon;

  /// 行尾控件（如二级菜单入口的 ›、快捷键提示）；选择项里占据对勾格。
  final Widget? trailingIcon;

  /// 文字下方的一行说明，通常是 `Text`。
  final Widget? summary;

  /// 危险操作（如删除）：文字与图标使用 `colorScheme.error`。
  final bool destructive;

  /// 单选 / 勾选菜单里这一项是否为当前值；null 表示普通动作项。
  ///
  /// 非 null 时同时写进语义（读屏读出“已选中”）；为 true 时行尾显示对勾。
  final bool? selected;

  /// 点按后是否关闭菜单。
  final bool closeOnActivate;

  /// 外部指定的高亮（桌面文字右键菜单的方向键高亮）。
  final bool highlighted;

  /// 行的焦点（二级菜单入口用它在收起时把焦点还给自己）。
  final FocusNode? focusNode;

  void _activate(BuildContext context) {
    if (!context.mounted) return;
    final anchor = ExpressiveMenuAnchorState.maybeOf(context);
    if (anchor != null) {
      if (!anchor.interactive) return;
      if (closeOnActivate) anchor.close();
    }
    if (closeOnActivate) {
      // 先让焦点回到触发控件，再执行动作：动作若打开对话框或新页面，
      // 关闭后焦点能正确落回入口。
      FocusManager.instance.applyFocusChangesIfNeeded();
    }
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final isSelected = selected ?? false;
    final Widget? trailing =
        trailingIcon ??
        (selected == null
            ? null
            : SizedBox.square(
                dimension: ExpressiveMenuRowMetrics.checkCell,
                child: isSelected
                    ? const Center(
                        child: FaIcon(
                          FontAwesomeIcons.check,
                          size: ExpressiveMenuRowMetrics.checkSize,
                        ),
                      )
                    : null,
              ));
    return ExpressiveMenuRowInk(
      onTap: enabled ? () => _activate(context) : null,
      focusNode: focusNode,
      highlighted: highlighted,
      selected: selected,
      child: ExpressiveMenuRowContent(
        enabled: enabled,
        selected: isSelected,
        destructive: destructive,
        leadingIcon: leadingIcon,
        summary: summary,
        trailing: trailing,
        child: child,
      ),
    );
  }
}

/// 菜单行胶囊里的排版：内边距、前置图标格、文字与说明、行尾格；颜色按状态取。
/// 菜单项与二级菜单的标题行共用，变形起止两端逐像素一致。
class ExpressiveMenuRowContent extends StatelessWidget {
  const ExpressiveMenuRowContent({
    super.key,
    required this.child,
    this.trailing,
    this.enabled = true,
    this.selected = false,
    this.destructive = false,
    this.leadingIcon,
    this.summary,
  });

  final Widget child;
  final Widget? trailing;
  final bool enabled;
  final bool selected;
  final bool destructive;
  final Widget? leadingIcon;
  final Widget? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final disabled = colors.onSurface.withValues(alpha: 0.38);
    final titleColor = !enabled
        ? disabled
        : destructive
        ? colors.error
        : selected
        ? colors.primary
        : colors.onSurface;
    final summaryColor = !enabled
        ? disabled
        : selected
        ? colors.primary
        : colors.onSurfaceVariant;
    final leading = leadingIcon;
    final summary = this.summary;
    final trailing = this.trailing;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DefaultTextStyle.merge(
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: ExpressiveMenuRowMetrics.titleSize,
            height: ExpressiveMenuRowMetrics.titleHeight,
            fontWeight: FontWeight.w500,
            color: titleColor,
          ),
          child: child,
        ),
        if (summary != null)
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium?.copyWith(color: summaryColor),
            child: summary,
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ExpressiveMenuRowMetrics.horizontalPadding,
        vertical: ExpressiveMenuRowMetrics.verticalPadding,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ExpressiveMenuRowMetrics.maxTextWidth,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (leading != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: ExpressiveMenuRowMetrics.iconGap,
                        ),
                        child: SizedBox.square(
                          dimension: ExpressiveMenuRowMetrics.iconBox,
                          child: Center(
                            child: IconTheme.merge(
                              data: IconThemeData(
                                size: ExpressiveMenuRowMetrics.iconSize,
                                color: titleColor,
                              ),
                              child: ExcludeSemantics(child: leading),
                            ),
                          ),
                        ),
                      ),
                    Flexible(child: text),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ExpressiveMenuRowMetrics.trailingGap,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  size: ExpressiveMenuRowMetrics.checkSize,
                  color: enabled
                      ? (selected ? colors.primary : colors.onSurfaceVariant)
                      : disabled,
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: summaryColor),
                  child: trailing,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
