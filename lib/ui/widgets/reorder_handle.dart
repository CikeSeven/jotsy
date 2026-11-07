import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';
import '../../l10n/app_localizations.dart';

/// 可排序列表的拖动手柄：按住即拖（不经过长按），全应用只用这一款。
///
/// 外观：2 × 3 的圆点握把。按下时圆点后面长出一块 `secondaryContainer` 竖向
/// 胶囊、圆点转为 `onSecondaryContainer`（“握住了”）；拖起后这份握住状态由
/// 拖起的那一行接着显示（见 [ReorderHandleLift]），落下时随拖起动画一起褪去。
/// 桌面上鼠标悬停时是一层淡淡的状态层，指针为抓手。
///
/// 触控区固定 [extent] × [extent] 且整块不透明命中：以前各列表用 `Padding`
/// 包一个 14px 图标，而 `Padding` 的留白不参与命中测试，实际只有图标本身那十几
/// 像素能按到，要很准才拿得起来。
///
/// 输入：[index] 为条目在可排序列表中的位置；[enabled] 为 false 时（如该行
/// 正在收起删除）不能拿起、圆点变淡；[semanticLabel] 为读屏标签，缺省为
/// “拖动排序”。副作用：无，拖动由所在的可排序列表处理（拿起时的触觉反馈也在
/// 列表的 `onReorderStart` 里给）。
class ReorderHandle extends StatefulWidget {
  const ReorderHandle({
    super.key,
    required this.index,
    this.enabled = true,
    this.semanticLabel,
  });

  /// 触控区边长，满足 Material 的 48dp 最小触控目标。
  static const double extent = 48;

  final int index;
  final bool enabled;
  final String? semanticLabel;

  @override
  State<ReorderHandle> createState() => _ReorderHandleState();
}

class _ReorderHandleState extends State<ReorderHandle> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    // 拖起后原行换成占位、本组件已卸载，但按下时记下的命中路径仍会把松手
    // 事件送到这里，所以要先判 mounted。
    if (mounted && _pressed != value) {
      setState(() => _pressed = value);
    }
  }

  void _setHovered(bool value) {
    if (mounted && _hovered != value) {
      setState(() => _hovered = value);
    }
  }

  @override
  void didUpdateWidget(ReorderHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 按住时被禁用（如该行开始收起删除）：松手事件可能不再送达，先复位。
    if (!widget.enabled) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final lift = ReorderHandleLift.maybeOf(context);
    final Widget grip;
    if (lift != null) {
      // 拖起的副本：拿起时立即是握住（与按下时的原行一致，不闪一下）；落下
      // 回位时动画反向，跟着回落到常态，与原行重新出现时的常态接上。
      grip = AnimatedBuilder(
        animation: lift,
        builder: (BuildContext context, Widget? _) {
          final settling =
              lift.status == AnimationStatus.reverse ||
              lift.status == AnimationStatus.dismissed;
          return _ReorderGrip(
            held: settling ? ExpressiveMotion.effects.transform(lift.value) : 1,
            hovered: false,
            enabled: enabled,
          );
        },
      );
    } else {
      grip = TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _pressed && enabled ? 1 : 0),
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        curve: ExpressiveMotion.effects,
        builder: (BuildContext context, double held, Widget? _) =>
            _ReorderGrip(held: held, hovered: _hovered, enabled: enabled),
      );
    }
    return Semantics(
      label: widget.semanticLabel ?? context.l10n.commonDragToReorder,
      child: ReorderableDragStartListener(
        index: widget.index,
        enabled: enabled,
        child: MouseRegion(
          cursor: !enabled
              ? MouseCursor.defer
              : _pressed
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          // 不透明命中：整块 48 × 48 都能按到，不只是中间的圆点。
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (PointerDownEvent event) {
              // 与列表的拖动识别器一致，只认主键（触摸也是主键），右键不算。
              if (enabled && (event.buttons & kPrimaryButton) != 0) {
                _setPressed(true);
              }
            },
            onPointerUp: (_) => _setPressed(false),
            onPointerCancel: (_) => _setPressed(false),
            child: SizedBox.square(
              dimension: ReorderHandle.extent,
              child: grip,
            ),
          ),
        ),
      ),
    );
  }
}

/// 标记“这是拖起的那一行”：可排序列表的 proxyDecorator 用它包住拖起的副本，
/// 副本里的 [ReorderHandle] 就保持握住状态，看得出手里拿着的是哪一行。
///
/// 拖起的副本是在 Overlay 里新建的一份，按下时原行里的状态带不过去，所以按
/// [animation]（proxyDecorator 收到的拖起动画：拿起时 0→1，松手回位时 1→0）
/// 来定，见 [ReorderHandle]。新增可排序列表的 proxyDecorator 必须包这一层。
class ReorderHandleLift extends InheritedWidget {
  const ReorderHandleLift({
    super.key,
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ReorderHandleLift>()
      ?.animation;

  @override
  bool updateShouldNotify(ReorderHandleLift oldWidget) =>
      animation != oldWidget.animation;
}

/// 握把的一帧：[held] 为握住程度（0 常态 → 1 握住），按它在常态与握住的
/// 颜色、胶囊大小之间插值。
class _ReorderGrip extends StatelessWidget {
  const _ReorderGrip({
    required this.held,
    required this.hovered,
    required this.enabled,
  });

  final double held;
  final bool hovered;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final idleDot = scheme.onSurfaceVariant.withValues(
      alpha: enabled ? 0.8 : 0.38,
    );
    // 悬停时先有一层淡状态层（与 M3 悬停状态层同为 8%），握住时转为容器色。
    final hover = hovered && enabled;
    final idleFill = hover
        ? scheme.onSurface.withValues(alpha: 0.08)
        : scheme.secondaryContainer.withValues(alpha: 0);
    return CustomPaint(
      painter: _ReorderGripPainter(
        fill: Color.lerp(idleFill, scheme.secondaryContainer, held)!,
        dot: Color.lerp(idleDot, scheme.onSecondaryContainer, held)!,
        // 胶囊按下时从中间长出来；悬停时状态层已是满尺寸，不再缩放。
        pillScale: hover ? 1 : lerpDouble(0.6, 1, held)!,
      ),
    );
  }
}

class _ReorderGripPainter extends CustomPainter {
  const _ReorderGripPainter({
    required this.fill,
    required this.dot,
    required this.pillScale,
  });

  final Color fill;
  final Color dot;
  final double pillScale;

  /// 胶囊尺寸：竖向，比圆点阵四周各宽出一圈，读起来是“一块握把”。
  static const Size _pill = Size(28, 40);

  /// 圆点半径与圆心间距（2 列 × 3 行，与 Material 的 drag_indicator 比例相近）。
  static const double _dotRadius = 1.75;
  static const double _dotGap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (fill.a > 0) {
      final pill = Rect.fromCenter(
        center: center,
        width: _pill.width * pillScale,
        height: _pill.height * pillScale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pill, Radius.circular(pill.width / 2)),
        Paint()..color = fill,
      );
    }
    final paint = Paint()..color = dot;
    for (final dx in const <double>[-0.5, 0.5]) {
      for (final dy in const <double>[-1, 0, 1]) {
        canvas.drawCircle(
          center + Offset(dx * _dotGap, dy * _dotGap),
          _dotRadius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ReorderGripPainter oldDelegate) =>
      fill != oldDelegate.fill ||
      dot != oldDelegate.dot ||
      pillScale != oldDelegate.pillScale;
}
