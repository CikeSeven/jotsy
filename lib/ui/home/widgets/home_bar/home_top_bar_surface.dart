import 'package:flutter/widgets.dart';

import '../../../widgets/glass/glass_surface.dart';
import 'home_chrome_scope.dart';

/// 首页 Tab 顶栏的底：实色时就是页面原来画的那块颜色，玻璃时换成
/// 直角、贴边的 [GlassSurface]。
///
/// 实色分支只有一个 [ColoredBox]，不多包任何会改变布局或绘制的节点：
/// 没有 [HomeChromeScope]（独立使用、单页测试）或顶栏不用玻璃时，渲染结果
/// 与改版前逐像素一致。高对比度时玻璃退回不透明底色、不模糊（见
/// `HomeBarResolvedStyle.translucent`），但仍保留玻璃顶栏的结构。
class HomeTopBarSurface extends StatelessWidget {
  const HomeTopBarSurface({
    super.key,
    required this.solidColor,
    this.showHairline = true,
    this.grouped = false,
    required this.child,
  });

  /// 实色时的底色（页面原来画的颜色，如 surface 或日记页的页面底色）。
  final Color solidColor;

  /// 玻璃时是否画底部细线（还要用户开着描边）。
  final bool showHairline;

  /// 是否与同一 BackdropGroup 下的其他玻璃共用背景（见 [GlassSurface.grouped]）。
  final bool grouped;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = HomeChromeScope.maybeStyleOf(context);
    if (style == null || !style.glassTopBars) {
      return ColoredBox(color: solidColor, child: child);
    }
    return GlassSurface(
      fill: style.fill,
      blur: style.translucent,
      blurSigma: style.blurSigma,
      bottomHairline: showHairline && style.border ? style.hairlineColor : null,
      grouped: grouped,
      child: child,
    );
  }
}
