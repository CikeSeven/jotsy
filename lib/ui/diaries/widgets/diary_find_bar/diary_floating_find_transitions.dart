import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/glass/glass_reveal.dart';

/// 查找栏所在悬浮卡片的出现与收起（编辑页键盘收着时打开查找、预览页的
/// 查找栏）：出现时与 `ExpressiveEntrance` 一样从下方升起（自身高度的 8%）
/// 并淡入；[visible] 变成 false 时反向播放，播完回调 [onHidden]，页面随后
/// 把它从树里拿掉。收起途中又变回 true 时从当前进度升回，不重新开始。
///
/// 收起的过渡里不接收点按（查找已经关了，卡片只是在离场）。玻璃时淡入淡出
/// 交给子树里的玻璃表面（[GlassReveal]），不套 Opacity：玻璃放进透明度层
/// 后采不到下面的正文。减少动画时近乎瞬时（[ExpressiveMotion.durationNonZero]：
/// 回调在下一帧而不是在构建里同步发生）。
class DiaryFloatingPresence extends StatefulWidget {
  const DiaryFloatingPresence({
    super.key,
    required this.visible,
    required this.child,
    this.glass = false,
    this.onHidden,
  });

  final bool visible;
  final bool glass;
  final VoidCallback? onHidden;
  final Widget child;

  @override
  State<DiaryFloatingPresence> createState() => _DiaryFloatingPresenceState();
}

class _DiaryFloatingPresenceState extends State<DiaryFloatingPresence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener(_onStatus);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = ExpressiveMotion.durationNonZero(
      context,
      ExpressiveMotion.medium,
    );
    if (!_started) {
      _started = true;
      if (widget.visible) _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(DiaryFloatingPresence old) {
    super.didUpdateWidget(old);
    if (old.visible == widget.visible) return;
    widget.visible ? _controller.forward() : _controller.reverse();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !widget.visible) {
      widget.onHidden?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (BuildContext context, Widget? child) {
          final progress = ExpressiveMotion.effects.transform(
            _controller.value,
          );
          final moved = FractionalTranslation(
            translation: Offset(0, 0.08 * (1 - progress)),
            child: child,
          );
          return widget.glass
              ? GlassReveal(progress: progress, child: moved)
              : Opacity(opacity: progress, child: moved);
        },
      ),
    );
  }
}

/// 悬浮卡片里两种内容的切换（编辑页：工具栏 ↔ 查找栏）：卡片本身不动、
/// 不透明，只在卡片里交叉淡化——新内容淡入、旧内容淡出，卡片的高度由外层
/// 的 `AnimatedSize` 补间。
///
/// 排布：显示中的那一个照常占高度；淡出的那一个不占高度，贴着底边画
/// （[_FadingOut]），被卡片与外层补间的裁剪截住，不会把卡片撑高，也不
/// 接收点按。两个都各自只在树里出现一次、位置固定：来回切换时状态（工具栏
/// 的面板、查找框的焦点）不会被另一份复制抢走；淡出结束后才拿掉。
class DiaryFloatingContentSwap extends StatefulWidget {
  const DiaryFloatingContentSwap({
    super.key,
    required this.showSecond,
    this.first,
    this.second,
  });

  /// 显示 [second]（查找栏）；false 时显示 [first]（工具栏）。
  final bool showSecond;
  final Widget? first;
  final Widget? second;

  @override
  State<DiaryFloatingContentSwap> createState() =>
      _DiaryFloatingContentSwapState();
}

class _DiaryFloatingContentSwapState extends State<DiaryFloatingContentSwap>
    with SingleTickerProviderStateMixin {
  /// 0 为显示 first，1 为显示 second。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.showSecond ? 1 : 0,
  )..addStatusListener(_onStatus);

  /// 淡出播完：重建一次，把旧内容拿掉。
  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = ExpressiveMotion.durationNonZero(
      context,
      ExpressiveMotion.medium,
    );
  }

  @override
  void didUpdateWidget(DiaryFloatingContentSwap old) {
    super.didUpdateWidget(old);
    if (old.showSecond == widget.showSecond) return;
    widget.showSecond ? _controller.forward() : _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 最近一次给出的两份内容：淡出的那一份调用方可能已经不再给（编辑页的
  /// 工具栏随焦点离开正文而不显示），淡出期间沿用最后一次的。
  Widget? _lastFirst;
  Widget? _lastSecond;

  @override
  Widget build(BuildContext context) {
    final showSecond = widget.showSecond;
    _lastFirst = widget.first ?? (showSecond ? _lastFirst : null);
    _lastSecond = widget.second ?? (showSecond ? null : _lastSecond);
    final first = _lastFirst;
    final second = _lastSecond;
    // 淡出完成（控制器停在目标一端）后才把旧内容拿掉。
    final keepFirst = first != null && (!showSecond || _controller.value < 1);
    final keepSecond = second != null && (showSecond || _controller.value > 0);
    if (!keepFirst) _lastFirst = widget.first;
    if (!keepSecond) _lastSecond = widget.second;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        if (keepFirst)
          _SwapChild(
            key: const ValueKey<String>('swap-first'),
            fadingOut: showSecond,
            opacity: ReverseAnimation(_controller),
            child: first,
          ),
        if (keepSecond)
          _SwapChild(
            key: const ValueKey<String>('swap-second'),
            fadingOut: !showSecond,
            opacity: _controller,
            child: second,
          ),
      ],
    );
  }
}

class _SwapChild extends StatelessWidget {
  const _SwapChild({
    super.key,
    required this.fadingOut,
    required this.opacity,
    required this.child,
  });

  final bool fadingOut;
  final Animation<double> opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _FadingOut(
      active: fadingOut,
      child: IgnorePointer(
        ignoring: fadingOut,
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: opacity,
            curve: ExpressiveMotion.effects,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// [active] 时不占高度（宽度照常），孩子按自己的高度贴着底边往上画；否则
/// 就是孩子本身的尺寸。同一个渲染对象在两种状态之间切换，孩子的状态不变。
class _FadingOut extends SingleChildRenderObjectWidget {
  const _FadingOut({required this.active, super.child});

  final bool active;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFadingOut(active);

  @override
  void updateRenderObject(BuildContext context, _RenderFadingOut renderObject) {
    renderObject.active = active;
  }
}

class _RenderFadingOut extends RenderProxyBox {
  _RenderFadingOut(this._active);

  bool _active;
  set active(bool value) {
    if (value == _active) return;
    _active = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = _active
        ? constraints.constrain(Size(child.size.width, 0))
        : child.size;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.paintChild(
      child,
      offset + Offset(0, size.height - child.size.height),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_active) return false;
    return super.hitTestChildren(result, position: position);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(0, size.height - child.size.height, 0, 1);
  }
}
