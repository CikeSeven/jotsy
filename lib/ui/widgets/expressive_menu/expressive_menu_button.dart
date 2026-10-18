import 'package:flutter/material.dart';

import 'expressive_menu_anchor.dart';

/// 图标按钮入口的 [ExpressiveMenuAnchor]：自带菜单控制器与焦点，点按开合。
///
/// 用于顶栏、列表行尾的“更多操作”（调用方传入现有的
/// `FaIcon(FontAwesomeIcons.ellipsisVertical, …)`）。按钮在语义上标注
/// 展开 / 收起，收起动画一开始即视为收起。
class ExpressiveMenuButton extends StatefulWidget {
  const ExpressiveMenuButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.items,
    this.placement = ExpressiveMenuPlacement.end,
    this.enabled = true,
  });

  final String tooltip;
  final Widget icon;

  /// 菜单内容，通常是若干 [ExpressiveMenuItem]。
  final List<Widget> items;
  final ExpressiveMenuPlacement placement;
  final bool enabled;

  @override
  State<ExpressiveMenuButton> createState() => _ExpressiveMenuButtonState();
}

class _ExpressiveMenuButtonState extends State<ExpressiveMenuButton> {
  final FocusNode _focus = FocusNode(debugLabel: 'ExpressiveMenuButton');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpressiveMenuAnchor(
      childFocusNode: _focus,
      placement: widget.placement,
      menuChildren: widget.items,
      builder:
          (BuildContext context, ExpressiveMenuAnchorState menu, Widget? _) =>
              // 合并进按钮自己的语义节点：读屏在同一个焦点上读到“按钮、已展开”。
              MergeSemantics(
                child: Semantics(
                  expanded: menu.isExpanded,
                  child: IconButton(
                    focusNode: _focus,
                    tooltip: widget.tooltip,
                    onPressed: widget.enabled ? menu.toggle : null,
                    icon: widget.icon,
                  ),
                ),
              ),
    );
  }
}
