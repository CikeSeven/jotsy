import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import 'expressive_menu_geometry.dart';
import 'expressive_menu_motion.dart';

/// 面板里登记的一行：它的 render box、能否点按与点按后要做的事。
class ExpressiveMenuRowHandle {
  RenderBox? box;
  bool enabled = false;
  VoidCallback? activate;
}

/// 一块面板的跟手滑选与高亮胶囊（移植自 NexioSchedule 的
/// DropdownPanelDragSelect，Sliding 遮罩）。
///
/// - 行经 [ExpressiveMenuSelectionScope] 登记；面板的唯一点按手势在这里：
///   按下即在手指下那一行亮起胶囊，按住上下滑动时胶囊以弹簧（阻尼比 0.85、
///   刚度 700）连贯滑到新的一行（每换一行一次轻触感），松手执行手指下那一行；
///   滑出各行时胶囊淡出、位置停在最近一行，松手不执行。
/// - 面板长到 98% 前不接管（展开途中的点按被忽略）；内容装不下需要滚动时
///   不滑选，手指移动超过 12dp 视为滚动、松手不执行，只保留点选。
/// - 悬停、键盘聚焦与外部指定的高亮也用同一块胶囊（优先级：按住 > 指定 >
///   聚焦 > 悬停），胶囊淡入 90ms、淡出 220ms。
/// - 按压同时驱动面板的形变 [jelly]。
/// - 减少动画时胶囊直接到位、不形变。
class ExpressiveMenuSelection extends ChangeNotifier {
  ExpressiveMenuSelection({required TickerProvider vsync})
    : maskTop = AnimationController.unbounded(vsync: vsync),
      maskBottom = AnimationController.unbounded(vsync: vsync),
      maskAlpha = AnimationController(vsync: vsync);

  static final SpringDescription maskSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: 0.85);

  /// 内容装不下时，手指移动超过这个距离算滚动。
  static const double scrollSlop = 12;

  final AnimationController maskTop;
  final AnimationController maskBottom;
  final AnimationController maskAlpha;

  /// 行的位置都相对这个盒子（面板滚动内容，含上下留白）。
  RenderBox? Function() contentBox = () => null;

  /// 面板是否已可接管点按（菜单已长到 98%、且没被二级菜单盖住）。
  bool Function() ready = () => true;

  /// 内容是否一屏装得下（装不下时不滑选）。
  bool Function() fits = () => true;

  /// 是否减少动画。
  bool Function() reduceMotion = () => false;

  /// 这块面板的按压形变。
  ExpressiveMenuJelly? jelly;

  final List<ExpressiveMenuRowHandle> _rows = <ExpressiveMenuRowHandle>[];
  ExpressiveMenuRowHandle? _pressed;
  ExpressiveMenuRowHandle? _dragTarget;
  ExpressiveMenuRowHandle? _hovered;
  ExpressiveMenuRowHandle? _focused;
  ExpressiveMenuRowHandle? _highlighted;
  ExpressiveMenuRowHandle? _maskRow;
  int? _pointer;

  /// 胶囊当前的目标（显现 / 隐去）：按下与松开可能落在同一帧，那时透明度还没
  /// 离开 0，只看当前值会漏掉“隐去”，淡入跑完后胶囊一直亮着。
  bool _maskShown = false;
  Offset _down = Offset.zero;
  bool _scrolled = false;

  /// 正在按住的行（测试与调试用）。
  ExpressiveMenuRowHandle? get pressed => _pressed;

  void register(ExpressiveMenuRowHandle row) {
    if (!_rows.contains(row)) _rows.add(row);
  }

  void unregister(ExpressiveMenuRowHandle row) {
    _rows.remove(row);
    var changed = false;
    if (identical(_pressed, row)) {
      _pressed = null;
      changed = true;
    }
    if (identical(_dragTarget, row)) _dragTarget = null;
    if (identical(_hovered, row)) _hovered = null;
    if (identical(_focused, row)) _focused = null;
    if (identical(_highlighted, row)) _highlighted = null;
    if (changed) _updateMask();
  }

  /// [row] 在内容里的竖直范围；还没布局或已卸载时为 null。
  (double, double)? _span(ExpressiveMenuRowHandle row) {
    final box = row.box;
    final content = contentBox();
    if (box == null ||
        content == null ||
        !box.attached ||
        !content.attached ||
        !box.hasSize) {
      return null;
    }
    final top = MatrixUtils.transformPoint(
      box.getTransformTo(content),
      Offset.zero,
    ).dy;
    return (top, top + box.size.height);
  }

  ExpressiveMenuRowHandle? _rowAt(double y) {
    for (final row in _rows) {
      if (!row.enabled) continue;
      final span = _span(row);
      if (span != null && y >= span.$1 && y < span.$2) return row;
    }
    return null;
  }

  /// 没落在任何一行上：取最近的一行（滑到底即末项、滑到顶即首项）。
  ExpressiveMenuRowHandle? _nearest(double y) {
    ExpressiveMenuRowHandle? best;
    var distance = double.infinity;
    for (final row in _rows) {
      if (!row.enabled) continue;
      final span = _span(row);
      if (span == null) continue;
      final d = ((span.$1 + span.$2) / 2 - y).abs();
      if (d < distance) {
        distance = d;
        best = row;
      }
    }
    return best;
  }

  static bool _isPrimary(PointerEvent event) =>
      event.kind != PointerDeviceKind.mouse ||
      event.buttons & kPrimaryMouseButton != 0;

  void handlePointerDown(PointerDownEvent event) {
    if (_pointer != null || !_isPrimary(event) || !ready()) return;
    _pointer = event.pointer;
    _down = event.localPosition;
    _scrolled = false;
    if (!reduceMotion()) jelly?.down();
    final hit = _rowAt(_down.dy);
    _pressed = hit;
    _dragTarget = hit ?? _nearest(_down.dy);
    _updateMask();
  }

  void handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final delta = event.localPosition - _down;
    if (!reduceMotion()) jelly?.move(delta);
    if (_scrolled) return;
    if (!fits()) {
      if (delta.dx.abs() > scrollSlop || delta.dy.abs() > scrollSlop) {
        _scrolled = true;
        _pressed = null;
        _updateMask();
      }
      return;
    }
    final hit = _rowAt(event.localPosition.dy);
    if (hit != null && !identical(hit, _pressed)) {
      HapticFeedback.selectionClick();
    }
    _pressed = hit;
    _dragTarget = hit ?? _nearest(event.localPosition.dy);
    _updateMask();
  }

  void handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final target = _scrolled ? null : _pressed;
    _endPointer();
    if (target != null && target.enabled) target.activate?.call();
  }

  void handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _endPointer();
  }

  void _endPointer() {
    _pointer = null;
    _pressed = null;
    _dragTarget = null;
    jelly?.up();
    _updateMask();
  }

  void setHovered(ExpressiveMenuRowHandle row, bool value) {
    if (value) {
      _hovered = row;
    } else if (identical(_hovered, row)) {
      _hovered = null;
    }
    _updateMask();
  }

  void setFocused(ExpressiveMenuRowHandle row, bool value) {
    if (value) {
      _focused = row;
    } else if (identical(_focused, row)) {
      _focused = null;
    }
    _updateMask();
  }

  void setHighlighted(ExpressiveMenuRowHandle row, bool value) {
    if (value) {
      _highlighted = row;
    } else if (identical(_highlighted, row)) {
      _highlighted = null;
    }
    _updateMask();
  }

  /// 胶囊此刻该在哪一行、是否可见，并发起对应的过渡。
  void _updateMask() {
    final pointerDown = _pointer != null;
    final visibleRow = pointerDown
        ? _pressed
        : (_highlighted ?? _focused ?? _hovered);
    final geometryRow = pointerDown ? (_dragTarget ?? _maskRow) : visibleRow;
    final span = geometryRow == null ? null : _span(geometryRow);
    final reduced = reduceMotion();
    if (span != null) {
      _maskRow = geometryRow;
      if (reduced || maskAlpha.value < 0.01) {
        maskTop.value = span.$1;
        maskBottom.value = span.$2;
      } else {
        _springTo(maskTop, span.$1);
        _springTo(maskBottom, span.$2);
      }
    }
    final visible = visibleRow != null && span != null;
    final target = visible ? 1.0 : 0.0;
    final changed = visible != _maskShown;
    _maskShown = visible;
    if (reduced) {
      maskAlpha.value = target;
    } else if (changed) {
      maskAlpha.animateTo(
        target,
        duration: visible
            ? ExpressiveMotion.menuHighlightIn
            : ExpressiveMotion.menuHighlightOut,
        curve: ExpressiveMotion.menuHighlightCurve,
      );
    }
    notifyListeners();
  }

  void _springTo(AnimationController c, double target) => c.animateWith(
    SpringSimulation(
      maskSpring,
      c.value,
      target,
      c.velocity,
      tolerance: const Tolerance(distance: 0.01, velocity: 0.1),
    ),
  );

  @override
  void dispose() {
    maskTop.dispose();
    maskBottom.dispose();
    maskAlpha.dispose();
    super.dispose();
  }
}

/// 把面板的 [ExpressiveMenuSelection] 交给其中的行。
class ExpressiveMenuSelectionScope extends InheritedWidget {
  const ExpressiveMenuSelectionScope({
    super.key,
    required this.selection,
    required super.child,
  });

  final ExpressiveMenuSelection selection;

  static ExpressiveMenuSelection? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ExpressiveMenuSelectionScope>()
      ?.selection;

  @override
  bool updateShouldNotify(ExpressiveMenuSelectionScope oldWidget) =>
      !identical(selection, oldWidget.selection);
}

/// 画在各行背后的高亮胶囊：左右缩进 [inset]（与行的胶囊一致），17 的超椭圆，
/// `onSurface` 亮色 6% / 暗色 10%（NexioSchedule 的命中遮罩色）。
class ExpressiveMenuMaskPainter extends CustomPainter {
  ExpressiveMenuMaskPainter({
    required this.selection,
    required this.color,
    required this.inset,
  }) : super(
         repaint: Listenable.merge(<Listenable>[
           selection.maskTop,
           selection.maskBottom,
           selection.maskAlpha,
         ]),
       );

  final ExpressiveMenuSelection selection;
  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = selection.maskAlpha.value.clamp(0.0, 1.0);
    if (alpha <= 0) return;
    final rect = Rect.fromLTRB(
      inset,
      selection.maskTop.value,
      size.width - inset,
      selection.maskBottom.value,
    );
    if (rect.width <= 0 || rect.height <= 0) return;
    canvas.drawRSuperellipse(
      expressiveMenuShape(rect, kExpressiveMenuRowRadius),
      Paint()..color = color.withValues(alpha: color.a * alpha),
    );
  }

  @override
  bool shouldRepaint(ExpressiveMenuMaskPainter oldDelegate) =>
      !identical(selection, oldDelegate.selection) ||
      color != oldDelegate.color ||
      inset != oldDelegate.inset;
}
