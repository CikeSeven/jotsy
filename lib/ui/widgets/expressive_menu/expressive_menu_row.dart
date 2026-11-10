import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../../../app/theme/expressive_motion.dart';
import 'expressive_menu_motion.dart';

/// 菜单行的尺寸（移植自 miuix 的 DropdownDefaults）。
abstract final class ExpressiveMenuRowMetrics {
  /// 行左右内边距。
  static const double horizontalPadding = 20;

  /// 行上下内边距；首行上方与末行下方另有面板的 [panelPadding]，合起来与
  /// miuix 首末行的 20 相同。
  static const double verticalPadding = 12;

  /// 面板上下的留白（首行之上、末行之下）。
  static const double panelPadding = 8;

  /// 首末行合计的上 / 下内边距（[verticalPadding] + [panelPadding]）。
  static const double edgePadding = verticalPadding + panelPadding;

  /// 前置图标格的最小边长与它到文字的间距。
  static const double iconCell = 26;
  static const double iconGap = 12;
  static const double iconSize = 18;

  /// 行尾对勾（或 ›、自定义尾随控件）前的间距与对勾格边长。
  static const double trailingGap = 12;
  static const double checkCell = 20;
  static const double checkSize = 16;

  /// 二级菜单入口行尾 › 的格子（10 × 16）。
  static const Size chevronCell = Size(10, 16);

  /// 图标 + 文字那一段的最大宽度。
  static const double maxTextWidth = 216;
}

/// 面板内容的作用域：行在绘制按下高亮时据此判断自己是不是首行 / 末行，
/// 是的话把高亮延伸到面板顶 / 底边（面板上下各有 [ExpressiveMenuRowMetrics.panelPadding]
/// 的留白，miuix 首末行的高亮一直铺到面板边缘）。二级菜单的变形起点也按
/// 同样的范围取触发行。
class ExpressiveMenuRowEdges extends InheritedWidget {
  const ExpressiveMenuRowEdges({
    super.key,
    required this.contentKey,
    required super.child,
  });

  /// 面板的滚动内容（含上下留白）。
  final GlobalKey contentKey;

  static ExpressiveMenuRowEdges? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ExpressiveMenuRowEdges>();

  /// [row] 向上 / 向下延伸到面板边缘的量；不是首行 / 末行时为 0。
  EdgeInsets extensionFor(RenderBox row) {
    final content = contentKey.currentContext?.findRenderObject();
    if (content is! RenderBox ||
        !content.attached ||
        !row.attached ||
        !content.hasSize ||
        !row.hasSize) {
      return EdgeInsets.zero;
    }
    final top = MatrixUtils.transformPoint(
      row.getTransformTo(content),
      Offset.zero,
    ).dy;
    final below = content.size.height - (top + row.size.height);
    const reach = ExpressiveMenuRowMetrics.panelPadding + 0.5;
    return EdgeInsets.only(
      top: top <= reach ? math.max(0, top) : 0,
      bottom: below <= reach ? math.max(0, below) : 0,
    );
  }

  @override
  bool updateShouldNotify(ExpressiveMenuRowEdges oldWidget) =>
      contentKey != oldWidget.contentKey;
}

/// 菜单行的交互层：点按、悬停、键盘聚焦与按下高亮（移植自 miuix 的
/// MiuixIndication）。
///
/// 高亮是铺满整行的 `onSurface` 色块（首末行延伸到面板边缘、被面板圆角
/// 裁掉），透明度叠加：悬停 0.06、聚焦 0.08、按下 0.10，各自用 miuix 的
/// 弹簧过渡（按下 folme(1, 0.2)、松开 folme(0.95, 0.35)、悬停进出
/// folme(1, 0.6) / folme(0.96, 0.2)）。松开时先等按下的弹簧跑完再回落：
/// 快速轻点也能看到一次完整的闪烁。减少动画时直接到位。
///
/// 语义：一个按钮节点（合并行内文字），带选中 / 展开状态；Enter / 空格
/// 经 ActivateIntent 触发。
class ExpressiveMenuRowInk extends StatefulWidget {
  const ExpressiveMenuRowInk({
    super.key,
    required this.onTap,
    required this.child,
    this.focusNode,
    this.highlighted = false,
    this.selected,
    this.expanded,
  });

  /// 为 null 时整行禁用（无高亮、不可聚焦）。
  final VoidCallback? onTap;
  final Widget child;
  final FocusNode? focusNode;

  /// 外部指定的高亮（如桌面文字右键菜单的方向键高亮），与聚焦同一档。
  final bool highlighted;
  final bool? selected;
  final bool? expanded;

  @override
  State<ExpressiveMenuRowInk> createState() => _ExpressiveMenuRowInkState();
}

class _ExpressiveMenuRowInkState extends State<ExpressiveMenuRowInk>
    with SingleTickerProviderStateMixin {
  static const double _hoverAlpha = 0.06;
  static const double _focusAlpha = 0.08;
  static const double _pressAlpha = 0.10;

  static final SpringDescription _pressEnter = ExpressiveMenuMotion.folmeSpring(
    1,
    0.2,
  );
  static final SpringDescription _pressExit = ExpressiveMenuMotion.folmeSpring(
    0.95,
    0.35,
  );
  static final SpringDescription _hoverEnter = ExpressiveMenuMotion.folmeSpring(
    1,
    0.6,
  );
  static final SpringDescription _hoverExit = ExpressiveMenuMotion.folmeSpring(
    0.96,
    0.2,
  );

  late final AnimationController _overlay = AnimationController.unbounded(
    vsync: this,
  );
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  /// 正在跑的“按下”弹簧；松开时等它跑完再回落。
  TickerFuture? _pressAnimation;

  /// 每发起一次过渡加一：排队等按下弹簧的回落，若期间又有新过渡就作废。
  int _serial = 0;

  double get _target {
    var target = 0.0;
    if (_hovered) target += _hoverAlpha;
    if (_focused || widget.highlighted) target += _focusAlpha;
    if (_pressed) target += _pressAlpha;
    return target;
  }

  @override
  void didUpdateWidget(ExpressiveMenuRowInk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlighted != widget.highlighted) {
      _animate(widget.highlighted ? _hoverEnter : _hoverExit, release: false);
    }
    if (widget.onTap == null && oldWidget.onTap != null) {
      _pressed = false;
      _hovered = false;
      _animate(_hoverExit, release: true);
    }
  }

  void _animate(SpringDescription spring, {required bool release}) {
    final target = _target;
    final serial = ++_serial;
    if (ExpressiveMotion.reduceMotion(context)) {
      _overlay.value = target;
      return;
    }
    TickerFuture run() => _overlay.animateWith(
      SpringSimulation(
        spring,
        _overlay.value,
        target,
        _overlay.velocity,
        tolerance: const Tolerance(distance: 1e-3, velocity: 1e-2),
      ),
    );
    final pending = _pressAnimation;
    if ((release || target == 0) && pending != null && _overlay.isAnimating) {
      // 按下的弹簧还没跑完：等它跑完（被新过渡打断则不再回落）。
      pending.then((_) {
        if (mounted && serial == _serial) run();
      });
      return;
    }
    final future = run();
    _pressAnimation = release ? null : future;
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    _animate(value ? _pressEnter : _pressExit, release: !value);
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    _hovered = value;
    _animate(value ? _hoverEnter : _hoverExit, release: false);
  }

  void _setFocused(bool value) {
    if (_focused == value) return;
    _focused = value;
    _animate(value ? _hoverEnter : _hoverExit, release: false);
  }

  @override
  void dispose() {
    _overlay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final enabled = onTap != null;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.selected,
        expanded: widget.expanded,
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          enabled: enabled,
          mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (ActivateIntent intent) {
                onTap?.call();
                return null;
              },
            ),
          },
          onShowHoverHighlight: _setHovered,
          onShowFocusHighlight: _setFocused,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _setPressed(true) : null,
            onTapUp: enabled ? (_) => _setPressed(false) : null,
            onTapCancel: enabled ? () => _setPressed(false) : null,
            onTap: onTap,
            child: _RowHighlight(
              alpha: _overlay,
              color: Theme.of(context).colorScheme.onSurface,
              edges: ExpressiveMenuRowEdges.maybeOf(context),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 在行的背后画高亮色块；首末行向上 / 下延伸到面板边缘。
class _RowHighlight extends SingleChildRenderObjectWidget {
  const _RowHighlight({
    required this.alpha,
    required this.color,
    required this.edges,
    super.child,
  });

  final Animation<double> alpha;
  final Color color;
  final ExpressiveMenuRowEdges? edges;

  @override
  _RenderRowHighlight createRenderObject(BuildContext context) =>
      _RenderRowHighlight(alpha: alpha, color: color, edges: edges);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRowHighlight renderObject,
  ) {
    renderObject
      ..alpha = alpha
      ..color = color
      ..edges = edges;
  }
}

class _RenderRowHighlight extends RenderProxyBox {
  _RenderRowHighlight({
    required this._alpha,
    required this._color,
    required this._edges,
  });

  Animation<double> _alpha;
  set alpha(Animation<double> value) {
    if (value == _alpha) return;
    if (attached) _alpha.removeListener(markNeedsPaint);
    _alpha = value;
    if (attached) _alpha.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  ExpressiveMenuRowEdges? _edges;
  set edges(ExpressiveMenuRowEdges? value) {
    if (value == _edges) return;
    _edges = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _alpha.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _alpha.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final alpha = _alpha.value.clamp(0.0, 1.0);
    if (alpha > 0) {
      final extension = _edges?.extensionFor(this) ?? EdgeInsets.zero;
      final rect = Rect.fromLTRB(
        offset.dx,
        offset.dy - extension.top,
        offset.dx + size.width,
        offset.dy + size.height + extension.bottom,
      );
      context.canvas.drawRect(
        rect,
        Paint()..color = _color.withValues(alpha: _color.a * alpha),
      );
    }
    super.paint(context, offset);
  }
}
