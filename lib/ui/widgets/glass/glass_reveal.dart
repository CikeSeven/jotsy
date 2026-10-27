import 'package:flutter/widgets.dart';

/// 玻璃显现进度作用域：让子树里的 `GlassSurface` 按 [progress] 一起淡入 /
/// 淡出，用来代替整块淡入时套的 `Opacity` / `FadeTransition`。
///
/// 为什么需要它：玻璃的背景模糊要采样表面下方的页面，放进透明度层后只能
/// 采到层自己（空的），淡入途中先露出一块没有模糊的底，结束时模糊才“啪”地
/// 出现。改用本作用域后没有透明度层，玻璃表面自己按进度缩放底色、描边、
/// 细线、投影与模糊强度，并把它的内容放进玻璃里面的一层 `Opacity` 一起淡入
/// （内容的透明度层在模糊之上，不影响模糊采样）。
///
/// 用法约束（调用方必须遵守）：
/// - 只在子树主体**是玻璃表面**时用它代替 Opacity；经典（不透明）表面照旧
///   用 Opacity。由调用方按 `AppGlass.of(context).isGlass(component)` 决定。
/// - 子树里不在任何玻璃表面之内的内容不会淡入，会在进度变化时硬切。所以
///   淡入的整块必须都在一块玻璃里（如工具栏的按钮都在工具栏玻璃之内）。
/// - 嵌套时进度相乘（外 0.5 × 内 0.5 = 0.25），与嵌套 Opacity 的效果一致。
class GlassReveal extends StatelessWidget {
  const GlassReveal({super.key, required this.progress, required this.child});

  /// 本层的显现进度（0 完全透明、1 完全显现），与祖先的进度相乘。
  final double progress;
  final Widget child;

  /// 当前位置的累计显现进度；没有祖先作用域时为 1。会让调用方依赖最近的
  /// 作用域，进度变化时重建。
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassRevealScope>()?.value ??
      1;

  /// 是否存在祖先作用域（不建立依赖）。`GlassSurface` 据此决定是否给内容
  /// 包一层 Opacity：没有作用域时树结构与引入本组件前完全相同。
  static bool hasScope(BuildContext context) =>
      context.getElementForInheritedWidgetOfExactType<_GlassRevealScope>() !=
      null;

  @override
  Widget build(BuildContext context) {
    final value = (GlassReveal.of(context) * progress).clamp(0.0, 1.0);
    return _GlassRevealScope(value: value, child: child);
  }
}

/// 动画驱动的 [GlassReveal]：随 [progress] 每帧更新进度。
class GlassRevealTransition extends StatelessWidget {
  const GlassRevealTransition({
    super.key,
    required this.progress,
    required this.child,
  });

  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (BuildContext context, Widget? child) =>
          GlassReveal(progress: progress.value, child: child!),
    );
  }
}

class _GlassRevealScope extends InheritedWidget {
  const _GlassRevealScope({required this.value, required super.child});

  /// 已与祖先相乘的累计进度。
  final double value;

  @override
  bool updateShouldNotify(_GlassRevealScope oldWidget) =>
      value != oldWidget.value;
}
