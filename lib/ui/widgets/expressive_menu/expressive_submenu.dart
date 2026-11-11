import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'expressive_menu_anchor.dart';
import 'expressive_menu_item.dart';
import 'expressive_menu_row.dart';

/// 打开二级菜单的一项：行尾带 ›，点按后二级菜单从这一行的胶囊变形展开（miuix
/// 的级联方式，NexioSchedule 的样式）：胶囊（16 圆角）长成一块新面板（22 圆角）
/// 盖在主菜单上，顶部是这一行的副本（› 转向上方，点按收回），下面是分隔线与
/// [menuChildren]；主菜单缩到 0.95 并盖上半透明遮罩，点遮罩、点外部或返回都先
/// 收回二级菜单。
///
/// 级联深度上限为 2：二级菜单里再放 [ExpressiveSubmenuItem] 不会再展开。
///
/// [menuChildren] 在点按时取定：二级菜单显示期间外面重建不会刷新它。要随
/// 选择即时变化的内容（保持菜单打开的单选项的对勾）应放进自己维护选中态的
/// 子组件里。
class ExpressiveSubmenuItem extends StatefulWidget {
  const ExpressiveSubmenuItem({
    super.key,
    required this.child,
    required this.menuChildren,
    this.leadingIcon,
  });

  /// 条目文字；二级菜单顶部的标题行也用它。
  final Widget child;

  /// 前置图标，与 [ExpressiveMenuItem.leadingIcon] 相同。
  final Widget? leadingIcon;

  /// 二级菜单的内容，通常是若干 [ExpressiveMenuItem]。
  final List<Widget> menuChildren;

  @override
  State<ExpressiveSubmenuItem> createState() => _ExpressiveSubmenuItemState();
}

class _ExpressiveSubmenuItemState extends State<ExpressiveSubmenuItem> {
  /// 这一行的焦点：键盘打开二级菜单再收回时，焦点回到这一行。
  final FocusNode _focus = FocusNode(debugLabel: 'ExpressiveSubmenuItem');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpressiveMenuItem(
    closeOnActivate: false,
    focusNode: _focus,
    leadingIcon: widget.leadingIcon,
    trailingIcon: const ExpressiveSubmenuChevron(),
    onPressed: () => ExpressiveMenuAnchorState.maybeOf(
      context,
    )?.openSubmenu(widget, context, _focus),
    child: widget.child,
  );
}

/// 二级菜单入口行尾的 ›（RTL 为 ‹），9 × 14 的格子；在标题行里随 [turns]
/// 转向上方。
class ExpressiveSubmenuChevron extends StatelessWidget {
  const ExpressiveSubmenuChevron({super.key, this.turns});

  /// 转过的圈数；null 不转。
  final Animation<double>? turns;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    Widget icon = FaIcon(
      rtl ? FontAwesomeIcons.angleLeft : FontAwesomeIcons.angleRight,
      size: ExpressiveMenuRowMetrics.chevronCell.height,
    );
    final turns = this.turns;
    if (turns != null) icon = RotationTransition(turns: turns, child: icon);
    return SizedBox.fromSize(
      size: ExpressiveMenuRowMetrics.chevronCell,
      child: OverflowBox(
        maxWidth: ExpressiveMenuRowMetrics.chevronCell.height,
        child: icon,
      ),
    );
  }
}

/// 二级菜单顶部的标题行：入口行的副本（同一块胶囊、同样的排版），点按收回
/// 二级菜单；读屏读作“返回，标题”。变形开始时它与触发行逐像素重合，看起来
/// 就是那一行本身长成了面板；行尾 › 随 [arrow] 转向上方（LTR −90°、RTL +90°）。
class ExpressiveSubmenuHeader extends StatelessWidget {
  const ExpressiveSubmenuHeader({
    super.key,
    required this.item,
    required this.arrow,
    required this.onCollapse,
  });

  final ExpressiveSubmenuItem item;
  final Animation<double> arrow;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExpressiveMenuRowInk(
      onTap: onCollapse,
      expanded: true,
      child: ExpressiveMenuRowContent(
        leadingIcon: item.leadingIcon,
        trailing: ExpressiveSubmenuChevron(
          turns: arrow.drive(Tween<double>(begin: 0, end: rtl ? 0.25 : -0.25)),
        ),
        child: Semantics(
          label: MaterialLocalizations.of(context).backButtonTooltip,
          child: item.child,
        ),
      ),
    );
  }
}

/// 菜单里分组之间的分隔线：`outlineVariant` 1dp，左右缩进 18（与行内文字的
/// 起点对齐：行缩进 6 + 胶囊内边距 12）、上下各留 4（NexioSchedule / miuix 的
/// HorizontalDivider 为 1.5dp，实机上显得太粗，按用户反馈改为 1dp）。
class ExpressiveMenuDivider extends StatelessWidget {
  const ExpressiveMenuDivider({super.key});

  static const double inset = 18;
  static const double spacing = 4;
  static const double thickness = 1;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: inset, vertical: spacing),
    child: Divider(
      height: thickness,
      thickness: thickness,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}
