import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/app_platform.dart';
import 'expressive_menu_anchor.dart';

/// 图标按钮入口的 [ExpressiveMenuAnchor]（移植自 NexioSchedule 顶栏“更多”的
/// LiquidGlassDropdownMenu）：自带菜单控制器与焦点，点按开合。
///
/// 用于顶栏、列表行尾的“更多操作”（调用方传入现有的
/// `FaIcon(FontAwesomeIcons.ellipsisVertical, …)`）。按钮在语义上标注
/// 展开 / 收起，收起动画一开始即视为收起。
///
/// - 按钮与菜单是同一块玻璃：点按后面板从按钮那个 40 的圆长成面板、盖住按钮
///   （贴着圆的角对齐），按钮的图标随之淡出；收起时缩回按钮并带一下回弹。
/// - 按下不铺状态层、不起水波纹：形变即是按下的反馈，按下的圆还会从面板
///   25 的圆角上露出来。悬停与键盘聚焦仍有高亮。
/// - Android 上打开时给一次 CONTEXT_CLICK 触感（Flutter 的 heavyImpact 在
///   Android 上即这一档）。
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

  void _toggle(ExpressiveMenuAnchorState menu) {
    if (!menu.isExpanded && AppPlatform.isAndroid) {
      HapticFeedback.heavyImpact();
    }
    menu.toggle();
  }

  @override
  Widget build(BuildContext context) {
    return ExpressiveMenuAnchor(
      childFocusNode: _focus,
      placement: widget.placement,
      iconTrigger: true,
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
                    onPressed: widget.enabled ? () => _toggle(menu) : null,
                    style: _noPressFeedback,
                    icon: widget.icon,
                  ),
                ),
              ),
    );
  }
}
