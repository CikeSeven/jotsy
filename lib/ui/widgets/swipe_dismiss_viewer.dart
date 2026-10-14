import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/expressive_motion.dart';

/// 看图页的“下拉关闭”。
///
/// 输入：[enabled] 为 false（内容已放大、没有图片）时不参与手势竞争，拖动交给
/// InteractiveViewer 平移；[onDismiss] 在松手决定关闭时调用（通常是 pop）。
/// 输出：[builder] 收到外围元素（背景、顶栏）应有的不透明度，以及已经施加跟手
/// 位移/缩放的 [child]。副作用：越过关闭阈值的瞬间轻震一次。
///
/// - 跟手：内容随手指纵向移动并按距离缩小到 [_minScale]，背景与顶栏按距离淡出，
///   都直接映射手指位置，不做补间；
/// - 松手：越过阈值（视口高度的 15%）或沿拖动方向快速甩动即关闭，内容停在松手
///   处，交给路由淡出与 Hero 飞回；否则以 spatial 弹簧回位；
/// - 纵向拖动识别器的触发阈值（18）小于 InteractiveViewer 的平移阈值（36），未放大
///   时竖向拖动由这里接管，水平拖动仍属于外层 PageView 翻页。
class SwipeDismissViewer extends StatefulWidget {
  const SwipeDismissViewer({
    super.key,
    required this.enabled,
    required this.onDismiss,
    required this.child,
    required this.builder,
  });

  final bool enabled;
  final VoidCallback onDismiss;
  final Widget child;
  final Widget Function(
    BuildContext context,
    double chromeOpacity,
    Widget content,
  )
  builder;

  @override
  State<SwipeDismissViewer> createState() => _SwipeDismissViewerState();
}

class _SwipeDismissViewerState extends State<SwipeDismissViewer>
    with SingleTickerProviderStateMixin {
  static const double _thresholdFraction = 0.15;
  static const double _flingVelocity = 800;
  static const double _minScale = 0.82;

  /// 内容的纵向位移（逻辑像素），正值向下。
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);
  late final AnimationController _settle = AnimationController(vsync: this)
    ..addListener(_applySettleFrame);

  /// 回弹起点；回弹过程按 spatial 曲线从这里回到 0（允许轻微越过）。
  double _settleFrom = 0;
  double _extent = 1;
  bool _armed = false;
  bool _dismissed = false;

  double get _threshold => _extent * _thresholdFraction;

  @override
  void didUpdateWidget(covariant SwipeDismissViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 拖动途中开始缩放（第二根手指落下）会关闭本手势，内容需要回位。
    if (oldWidget.enabled && !widget.enabled && !_dismissed) {
      _settleBack();
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    _offset.dispose();
    super.dispose();
  }

  void _applySettleFrame() {
    _offset.value =
        _settleFrom * (1 - ExpressiveMotion.spatial.transform(_settle.value));
  }

  void _handleDragStart(DragStartDetails details) {
    _settle.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dismissed) {
      return;
    }
    _offset.value += details.delta.dy;
    final armed = _offset.value.abs() > _threshold;
    if (armed == _armed) {
      return;
    }
    _armed = armed;
    // 只在进入“松手即关闭”时震一次，来回拖动不连震。
    if (armed) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dismissed) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final offset = _offset.value;
    final flung =
        offset != 0 &&
        velocity.abs() > _flingVelocity &&
        velocity.sign == offset.sign;
    if (_armed || flung) {
      _dismissed = true;
      widget.onDismiss();
      return;
    }
    _settleBack();
  }

  void _handleDragCancel() {
    if (!_dismissed) {
      _settleBack();
    }
  }

  void _settleBack() {
    _armed = false;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (duration == Duration.zero || _offset.value == 0) {
      _settle.stop();
      _offset.value = 0;
      return;
    }
    _settleFrom = _offset.value;
    _settle
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _extent = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return GestureDetector(
          onVerticalDragStart: enabled ? _handleDragStart : null,
          onVerticalDragUpdate: enabled ? _handleDragUpdate : null,
          onVerticalDragEnd: enabled ? _handleDragEnd : null,
          onVerticalDragCancel: enabled ? _handleDragCancel : null,
          child: ValueListenableBuilder<double>(
            valueListenable: _offset,
            child: widget.child,
            builder: (BuildContext context, double offset, Widget? child) {
              final distance = offset.abs();
              final scale =
                  1 -
                  (1 - _minScale) *
                      (distance / (_extent * 0.5)).clamp(0.0, 1.0);
              final chromeOpacity =
                  1 - (distance / (_extent * 0.35)).clamp(0.0, 1.0);
              // 结构恒定：静止时是单位矩阵，RenderTransform 不会额外推图层。
              final content = Transform(
                alignment: Alignment.center,
                transform: Matrix4.translationValues(0, offset, 0)
                  ..scaleByDouble(scale, scale, 1, 1),
                child: child,
              );
              return widget.builder(context, chromeOpacity, content);
            },
          ),
        );
      },
    );
  }
}
