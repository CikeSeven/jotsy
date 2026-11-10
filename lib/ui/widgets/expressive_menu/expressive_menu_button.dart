import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import 'expressive_menu_anchor.dart';
import 'expressive_menu_motion.dart';

/// 图标按钮入口的 [ExpressiveMenuAnchor]（移植自 miuix 的
/// OverlayIconCascadingDropdownMenu）：自带菜单控制器与焦点，点按开合。
///
/// 用于顶栏、列表行尾的“更多操作”（调用方传入现有的
/// `FaIcon(FontAwesomeIcons.ellipsisVertical, …)`）。按钮在语义上标注
/// 展开 / 收起，收起动画一开始即视为收起。
///
/// - 菜单从按钮下方 8dp 处、结束边对齐按钮弹出（见 [ExpressiveMenuAnchor]）。
/// - 按住态：菜单开着时按钮背后保持一块 `onSurface` 10% 的圆（同 miuix 的
///   holdDown），收起动画结束才褪去；进出用 miuix 按下 / 松开的弹簧。
///   按下不起水波纹（miuix 的按下反馈是色块，不是涟漪）。
/// - Android 上打开时给一次 CONTEXT_CLICK 触感（Flutter 的 heavyImpact 在
///   Android 上即这一档，同 miuix 的 ContextClick）。
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
  static final ButtonStyle _noSplash = ButtonStyle(
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
      menuChildren: widget.items,
      builder:
          (BuildContext context, ExpressiveMenuAnchorState menu, Widget? _) =>
              // 合并进按钮自己的语义节点：读屏在同一个焦点上读到“按钮、已展开”。
              MergeSemantics(
                child: Semantics(
                  expanded: menu.isExpanded,
                  child: _HoldDown(
                    held: menu.isShowing,
                    child: IconButton(
                      focusNode: _focus,
                      tooltip: widget.tooltip,
                      onPressed: widget.enabled ? () => _toggle(menu) : null,
                      style: _noSplash,
                      icon: widget.icon,
                    ),
                  ),
                ),
              ),
    );
  }
}

/// 按钮背后的按住态色块：边长取按钮那个 40 的圆（不超过可用空间），
/// [held] 变化时以 miuix 的按下 / 松开弹簧淡入淡出。
class _HoldDown extends StatefulWidget {
  const _HoldDown({required this.held, required this.child});

  final bool held;
  final Widget child;

  @override
  State<_HoldDown> createState() => _HoldDownState();
}

class _HoldDownState extends State<_HoldDown>
    with SingleTickerProviderStateMixin {
  static const double _alpha = 0.10;
  static const double _diameter = 40;
  static final SpringDescription _enter = ExpressiveMenuMotion.folmeSpring(
    1,
    0.2,
  );
  static final SpringDescription _exit = ExpressiveMenuMotion.folmeSpring(
    0.95,
    0.35,
  );

  late final AnimationController _value = AnimationController.unbounded(
    vsync: this,
    value: widget.held ? 1 : 0,
  );

  @override
  void didUpdateWidget(_HoldDown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.held == widget.held) return;
    final target = widget.held ? 1.0 : 0.0;
    if (ExpressiveMotion.reduceMotion(context)) {
      _value.value = target;
      return;
    }
    _value.animateWith(
      SpringSimulation(
        widget.held ? _enter : _exit,
        _value.value,
        target,
        _value.velocity,
        tolerance: const Tolerance(distance: 1e-3, velocity: 1e-2),
      ),
    );
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _HoldDownPainter(
      value: _value,
      color: Theme.of(context).colorScheme.onSurface,
    ),
    child: widget.child,
  );
}

class _HoldDownPainter extends CustomPainter {
  _HoldDownPainter({required this.value, required this.color})
    : super(repaint: value);

  final Animation<double> value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = value.value.clamp(0.0, 1.0);
    if (t == 0) return;
    final radius = math.min(_HoldDownState._diameter, size.shortestSide) / 2;
    canvas.drawCircle(
      size.center(Offset.zero),
      radius,
      Paint()
        ..color = color.withValues(alpha: color.a * _HoldDownState._alpha * t),
    );
  }

  @override
  bool shouldRepaint(_HoldDownPainter oldDelegate) =>
      value != oldDelegate.value || color != oldDelegate.color;
}
