import 'package:flutter/material.dart';

/// 标记“这棵子树画在一块玻璃表面上”。
///
/// 由 `AppGlassSurface` 在玻璃内容外插入（只多这一个 InheritedWidget，不改
/// 变其他结构）。为什么需要它：面板、卡片里原本用不透明填充色区分的行与
/// 输入框（如发表面板的各行、标签搜索栏），在经典卡片上是“比卡片深一级”的
/// 底色；放到半透明的玻璃上就成了一格格遮住背景的实色补丁。子组件据
/// [OnGlass.of] 把这些填充换成半透明的 [wellColor]，即使“控件”本身仍是经典
/// 材质，只要所在的表面是玻璃。
///
/// 没有祖先时为 false，经典表面上的组件不受影响。
class OnGlass extends InheritedWidget {
  const OnGlass({super.key, required super.child});

  /// 当前位置是否在一块玻璃表面之内（有没有祖先 [OnGlass]）。建立依赖：
  /// 子树经 GlobalKey 移进 / 移出玻璃时调用方会被通知重建。
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnGlass>() != null;

  /// 玻璃上的“凹槽”填充色：用前景色 onSurface 的低透明度叠色代替不透明的
  /// 输入框填充色。取前景色而不是表面色，是因为玻璃底色可能是任意自定义色
  /// 或背景图：叠一层前景色在亮色下略深、暗色下略亮，总能和玻璃本身分开，
  /// 同时透出下面的背景。暗色下前景色更亮，同样透明度显得更跳，所以只略高
  /// 一点（6% / 8%）。
  static Color wellColor(ColorScheme scheme) => scheme.onSurface.withValues(
    alpha: scheme.brightness == Brightness.light ? 0.06 : 0.08,
  );

  @override
  bool updateShouldNotify(OnGlass oldWidget) => false;
}
