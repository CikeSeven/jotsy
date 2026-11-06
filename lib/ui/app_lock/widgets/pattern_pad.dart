// 3×3 图案输入板（DESIGN.md §5.31）。
//
// - 输入：是否可用、是否显示为出错（连线与点变 error 色）、清空信号；
// - 输出：开始画（[PatternPad.onStarted]）与画完（[PatternPad.onCompleted]，
//   格子序号 0–8，行优先）；
// - 副作用：每连上一个点一次 `selectionClick` 触觉。
//
// 手势：用 [Listener] 读原始指针（落点即可连上第一个点，不等拖动阈值），再
// 用 [EagerGestureRecognizer] 立即赢下手势竞技场——外层是可滚动的锁屏内容区
// （横屏或小窗时可滚动），否则竖着画会被滚动抢走。只跟踪第一根手指；鼠标
// 按住左键拖动同样可以画。
//
// 规则与系统图案锁一致：每个点只能连一次；两个点之间正好隔着一个没连过的点
// （同一行 / 列 / 对角线）时自动补上中间那个。
//
// 抬手后连线保留（核对中、被拒时变红），直到 [PatternPad.clearSignal] 变化
// 或下一次落指。正在画的时候忽略清空信号：落指时已经清过一次，外层随后因
// “开始画”发出的清空信号不能把刚连上的第一个点也清掉。

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';

class PatternPad extends StatefulWidget {
  const PatternPad({
    super.key,
    required this.enabled,
    required this.error,
    required this.clearSignal,
    required this.onStarted,
    required this.onCompleted,
    this.size = defaultSize,
  });

  static const double defaultSize = 300;
  static const double minSize = 220;

  final bool enabled;
  final bool error;
  final int clearSignal;
  final VoidCallback onStarted;
  final ValueChanged<List<int>> onCompleted;
  final double size;

  @override
  State<PatternPad> createState() => _PatternPadState();
}

class _PatternPadState extends State<PatternPad>
    with SingleTickerProviderStateMixin {
  final List<int> _nodes = <int>[];
  Offset? _pointer;
  int? _activePointer;

  /// 最近连上的点从小到大的弹出进度（0 → 1）。
  late final AnimationController _pop = AnimationController(
    vsync: this,
    value: 1,
  );

  @override
  void didUpdateWidget(PatternPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clearSignal != oldWidget.clearSignal && _activePointer == null) {
      _nodes.clear();
      _pointer = null;
    }
    if (!widget.enabled && _activePointer != null) {
      _activePointer = null;
      _pointer = null;
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  double get _cell => widget.size / 3;

  Offset _center(int node) =>
      Offset((node % 3 + 0.5) * _cell, (node ~/ 3 + 0.5) * _cell);

  /// 落在哪个点的感应范围里（半径约为格宽的 0.36）。
  int? _hit(Offset position) {
    final radius = _cell * 0.36;
    for (var node = 0; node < 9; node++) {
      if ((position - _center(node)).distance <= radius) return node;
    }
    return null;
  }

  void _add(int node) {
    if (_nodes.contains(node)) return;
    if (_nodes.isNotEmpty) {
      final last = _nodes.last;
      final r1 = last ~/ 3, c1 = last % 3, r2 = node ~/ 3, c2 = node % 3;
      // 两点之间正好隔一个点（行、列差都为偶数）时补上中间那个。
      if ((r1 + r2).isEven && (c1 + c2).isEven) {
        final middle = (r1 + r2) ~/ 2 * 3 + (c1 + c2) ~/ 2;
        if (middle != last && middle != node && !_nodes.contains(middle)) {
          _nodes.add(middle);
        }
      }
    }
    _nodes.add(node);
    HapticFeedback.selectionClick();
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    if (duration == Duration.zero) {
      _pop.value = 1;
    } else {
      _pop.duration = duration;
      _pop.forward(from: 0);
    }
  }

  void _handleDown(PointerDownEvent event) {
    if (!widget.enabled || _activePointer != null) return;
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    _activePointer = event.pointer;
    _nodes.clear();
    widget.onStarted();
    setState(() {
      _pointer = event.localPosition;
      final node = _hit(event.localPosition);
      if (node != null) _add(node);
    });
  }

  void _handleMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    setState(() {
      _pointer = event.localPosition;
      final node = _hit(event.localPosition);
      if (node != null) _add(node);
    });
  }

  void _handleUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _finish();
  }

  void _handleCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _finish();
  }

  void _finish() {
    _activePointer = null;
    setState(() => _pointer = null);
    if (_nodes.isNotEmpty) {
      widget.onCompleted(List<int>.unmodifiable(_nodes));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.passcodePatternSemantics,
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          EagerGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                EagerGestureRecognizer.new,
                (_) {},
              ),
        },
        child: Listener(
          onPointerDown: _handleDown,
          onPointerMove: _handleMove,
          onPointerUp: _handleUp,
          onPointerCancel: _handleCancel,
          child: AnimatedBuilder(
            animation: _pop,
            builder: (BuildContext context, Widget? child) => CustomPaint(
              size: Size.square(widget.size),
              painter: _PatternPainter(
                nodes: List<int>.of(_nodes),
                pointer: _pointer,
                cell: _cell,
                pop: _pop.value,
                enabled: widget.enabled,
                idleColor: scheme.onSurfaceVariant,
                activeColor: widget.error ? scheme.error : scheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.nodes,
    required this.pointer,
    required this.cell,
    required this.pop,
    required this.enabled,
    required this.idleColor,
    required this.activeColor,
  });

  final List<int> nodes;
  final Offset? pointer;
  final double cell;
  final double pop;
  final bool enabled;
  final Color idleColor;
  final Color activeColor;

  Offset _center(int node) =>
      Offset((node % 3 + 0.5) * cell, (node ~/ 3 + 0.5) * cell);

  @override
  void paint(Canvas canvas, Size size) {
    // 尺寸按 300 宽时的规格（点 12、选中 20、光晕 56、线 4）等比缩放。
    final scale = cell / 100;
    final alpha = enabled ? 1.0 : 0.38;
    if (nodes.isNotEmpty) {
      final line = Paint()
        ..color = activeColor.withValues(alpha: 0.85 * alpha)
        ..strokeWidth = 4 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(_center(nodes.first).dx, _center(nodes.first).dy);
      for (final node in nodes.skip(1)) {
        path.lineTo(_center(node).dx, _center(node).dy);
      }
      final tail = pointer;
      if (tail != null) path.lineTo(tail.dx, tail.dy);
      canvas.drawPath(path, line);
    }
    final idle = Paint()..color = idleColor.withValues(alpha: 0.55 * alpha);
    final active = Paint()..color = activeColor.withValues(alpha: alpha);
    final halo = Paint()..color = activeColor.withValues(alpha: 0.12 * alpha);
    for (var node = 0; node < 9; node++) {
      final center = _center(node);
      final index = nodes.indexOf(node);
      if (index < 0) {
        canvas.drawCircle(center, 6 * scale, idle);
        continue;
      }
      // 最近连上的点弹出（光晕与圆点从小到大），之前的保持原大小。
      final t = index == nodes.length - 1
          ? Curves.easeOutBack.transform(pop)
          : 1.0;
      canvas.drawCircle(center, 28 * scale * math.max(0.4, t), halo);
      canvas.drawCircle(center, 10 * scale * math.max(0.6, t), active);
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      !_sameNodes(old.nodes, nodes) ||
      old.pointer != pointer ||
      old.cell != cell ||
      old.pop != pop ||
      old.enabled != enabled ||
      old.idleColor != idleColor ||
      old.activeColor != activeColor;

  static bool _sameNodes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
