import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/todo_check_box.dart';
import 'todo_complete_motion.dart';

/// 待办的勾选方框：列表行左侧为 48dp 触控格里的 22dp 方框，详情头部为
/// 28dp、贴起始边（[size]、[alignment]）。
///
/// 按下时方框以真弹簧压到 [TodoCompleteMotion.pressedScale]，松手或取消时
/// 带着速度弹回；勾选动效（[check]，见 [TodoCompleteMotion]）里再弹过
/// [TodoCompleteMotion.bounceScale]。两者相乘：按住时勾选的那一下从压下的
/// 大小直接弹起，不先跳回原尺寸。停用（[enabled] 为 false）时淡化、不响应。
class TodoTileCheckButton extends StatefulWidget {
  const TodoTileCheckButton({
    super.key,
    required this.check,
    required this.checked,
    required this.enabled,
    required this.accent,
    required this.onAccent,
    required this.tint,
    required this.semanticsLabel,
    required this.onTap,
    this.size = 22,
    this.alignment = Alignment.center,
  });

  /// 勾选动效的进度（0~1，含停的一拍）。
  final Animation<double> check;
  final bool checked;
  final bool enabled;
  final Color? accent;
  final Color? onAccent;
  final Color? tint;
  final String? semanticsLabel;
  final VoidCallback onTap;
  final double size;
  final AlignmentGeometry alignment;

  @override
  State<TodoTileCheckButton> createState() => _TodoTileCheckButtonState();
}

class _TodoTileCheckButtonState extends State<TodoTileCheckButton>
    with SingleTickerProviderStateMixin {
  /// 按压缩放（1 为原尺寸）。无界：弹回时会略过 1 再落回。
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final Animation<double> _scale = _ProductAnimation(
    _press,
    widget.check.drive(TodoCompleteMotion.bounceScaleTween),
  );

  static final Tolerance _tolerance = Tolerance(distance: 1e-3, velocity: 1e-2);

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _pressTo(double target) => ExpressiveMotion.springTo(
    context,
    _press,
    target,
    spring: ExpressiveMotion.springSpatialFast,
    tolerance: _tolerance,
  );

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Semantics(
      checked: widget.checked,
      button: true,
      enabled: enabled,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: InkResponse(
        onTap: enabled ? widget.onTap : null,
        onTapDown: enabled
            ? (_) => _pressTo(TodoCompleteMotion.pressedScale)
            : null,
        onTapUp: enabled ? (_) => _pressTo(1) : null,
        onTapCancel: enabled ? () => _pressTo(1) : null,
        radius: widget.size,
        child: Align(
          alignment: widget.alignment,
          child: Opacity(
            opacity: enabled ? 1 : 0.38,
            child: ScaleTransition(
              scale: _scale,
              child: TodoCheckBoxVisual(
                checked: widget.checked,
                size: widget.size,
                accent: widget.accent,
                onAccent: widget.onAccent,
                tint: widget.tint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 两个动画值的乘积（按压缩放 × 勾选弹跳）。
class _ProductAnimation extends CompoundAnimation<double> {
  _ProductAnimation(Animation<double> first, Animation<double> next)
    : super(first: first, next: next);

  @override
  double get value => first.value * next.value;
}

/// 多选态的选择圆圈：选中为 `primary` 实心勾，未选为 `outline` 空心圆。
class TodoTileSelectionMark extends StatelessWidget {
  const TodoTileSelectionMark({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ExpressiveIconSwap(
        switchKey: selected,
        child: FaIcon(
          selected
              ? FontAwesomeIcons.solidCircleCheck
              : FontAwesomeIcons.circle,
          size: 21,
          color: selected ? scheme.primary : scheme.outline,
        ),
      ),
    );
  }
}
