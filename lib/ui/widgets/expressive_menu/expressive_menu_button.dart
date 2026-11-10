import 'package:flutter/material.dart';

import 'expressive_menu_anchor.dart';

/// 图标按钮入口的 [ExpressiveMenuAnchor]：自带菜单控制器与焦点，点按开合。
///
/// 用于顶栏、列表行尾的“更多操作”（调用方传入现有的
/// `FaIcon(FontAwesomeIcons.ellipsisVertical, …)`）。按钮在语义上标注
/// 展开 / 收起，收起动画一开始即视为收起。
///
/// 按钮本身长成菜单（[ExpressiveMenuAnchor.morph]）：点按后玻璃从按钮的圆
/// 以弹簧长成面板、盖住按钮，图标随之淡出；收起时缩回按钮、图标淡入。
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
  /// 按下不铺状态层、不起水波纹：按钮本身就长成菜单，形变即是按下的反馈；
  /// 而面板贴着按钮的角，28 的圆角比按钮 20 的半径收得更多，按下的圆会从
  /// 面板角上露出来，要到水波纹淡完才消失。悬停与键盘聚焦仍有高亮。
  static final ButtonStyle _noPressFeedback = ButtonStyle(
    overlayColor: WidgetStateProperty.resolveWith(
      (Set<WidgetState> states) =>
          states.contains(WidgetState.pressed) ? Colors.transparent : null,
    ),
    splashFactory: NoSplash.splashFactory,
  );

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
      morph: true,
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
                    style: _noPressFeedback,
                    // 玻璃长大时按钮的图标淡出，缩回按钮时再淡入。
                    icon: FadeTransition(
                      opacity: menu.triggerOpacity,
                      child: widget.icon,
                    ),
                  ),
                ),
              ),
    );
  }
}
