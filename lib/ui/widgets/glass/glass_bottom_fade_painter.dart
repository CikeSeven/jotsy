import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// 玻璃自上而下逐渐变透明：玻璃露出来的上半截是完整的玻璃，下半截（
/// [fadeFraction]）里底色与背景模糊（连同饱和度增强）按同一条曲线一起由
/// 完整淡到没有，下缘处什么都不剩。由 `GlassSurface` 画在背景模糊图层之内、
/// 内容之前，代替均匀的底色。
///
/// 只淡下半截：上半截排着顶栏的标题、状态栏图标与按钮，从顶端就开始淡的话
/// 上面那截薄得像没有底；下半截淡出，滚上来的内容在靠近下缘处逐渐露出来，
/// 下缘与页面连成一片。淡出段里自带底色的控件（搜索胶囊、标签）要换上更实
/// 的底（`HomeBarResolvedStyle.topBarControlFill`），否则会跟着玻璃一起没了。
///
/// 曲线是两端斜率为 0 的 S 形（[strengthAt]）：上端与完整的玻璃平滑相接，
/// 看不出从哪一行开始变淡；下端贴着 0 收尾，下缘不留一条线。
///
/// 玻璃可以比露出来的部分高（`GlassSurface.extendAbove`：日记页标签栏的玻璃
/// 往上铺到刊头之后，刊头收起时上面那截在滚动视图之外）。渐变按“露出来的
/// 那一段”的高度算：画布最上面 [overhang] 是往上铺的部分，其中此刻露出来的高度由
/// [visibleOverhang] 给出（null 即全部露出），没露出来的那截不画、并在能擦除
/// 时擦掉。露出的高度在布局阶段变化，这里只需要重画，所以直接作为 repaint
/// 监听，不经过重建。
///
/// 模糊怎么淡出（[eraseBackdrop]）：背景模糊会开一个离屏图层，图层的初始
/// 内容是“模糊后的背景”。这里用 [BlendMode.dstIn] 画一块自上而下由不透明
/// 到透明的矩形，图层里已有的像素就按这条透明度曲线被擦除；图层合成回
/// 页面时，擦掉的部分露出下方没有模糊的页面。所以必须先擦、后画底色
/// （否则底色也被擦一遍，曲线就乘了两次）。
///
/// 擦除只在背景模糊确实开了自己的离屏图层时成立，两种情况没有这个图层，
/// [eraseBackdrop] 必须为 false，否则擦掉的是图层外的页面本身：
/// - 模糊关闭（`BackdropFilter.enabled` 为 false）；
/// - 几块玻璃共用一次背景读取（`BackdropFilter.grouped` / `backdropGroupKey`）
///   且滤镜相同：Impeller 只算一次模糊、把结果直接画进父图层，不再开新图层，
///   子节点也直接画在父图层上——擦除会把页面擦成透明，屏幕上就是一块黑。
///   `GlassSurface` 渐变时因此不共用背景读取。
///
/// 为什么不用别的办法：
/// - 把玻璃放进 `ShaderMask` / `Opacity`：模糊只能采到遮罩图层自己（空的），
///   整块玻璃会失去模糊（`GlassSurface` 的约束同理）；
/// - 叠几条模糊半径递减的 `BackdropFilter`：每条都多一轮背景读取与模糊，
///   相邻两条的分界在文字上看得出一道道横线；
/// - 用片元着色器做连续变化的模糊：只有 Impeller 支持，桌面与测试的 Skia 上
///   没有，坐标还取决于外面有没有别的图层。
/// 这里只多几次矩形绘制，不多任何图层与模糊。
///
/// 两块渐变都是同一种颜色只变透明度（其中一块连颜色都不起作用），是遮罩
/// 而不是配色，属于“界面不用渐变色”之外的例外（DESIGN.md §2.2）。
class GlassBottomFadePainter extends CustomPainter {
  GlassBottomFadePainter({
    required this.fade,
    required this.fill,
    required this.eraseBackdrop,
    this.overhang = 0,
    this.visibleOverhang,
  }) : assert(overhang >= 0),
       super(repaint: visibleOverhang);

  /// 是否自上而下渐变；false 时露出来的部分是均匀的底色（打开顶栏分隔线、
  /// 高对比度时）。
  final bool fade;

  /// 玻璃的底色（已带透明度）；渐变时由它淡到全透明。
  final Color fill;

  /// 是否把背景模糊一起擦淡；只有画在已开离屏图层的 `BackdropFilter` 之内
  /// 才能为 true（见类注释）。
  final bool eraseBackdrop;

  /// 画布最上面往上铺出去的高度（`GlassSurface.extendAbove`）。
  final double overhang;

  /// 往上铺出去的部分此刻露出来多高；null 即 [overhang] 全部露出。
  final ValueListenable<double>? visibleOverhang;

  /// 渐变占玻璃露出高度的比例（自下缘往上量）；其上是完整的玻璃。
  static const double fadeFraction = 0.5;

  /// 透明度曲线的采样点数（含两端）。线性渐变在两个采样点之间是直线，
  /// 9 个点足够贴近 [strengthAt] 的 S 形，肉眼看不出折线。
  static const int _sampleCount = 9;

  /// 自上（0）而下（1）的强度：1 − smoothstep。两端的斜率都是 0。
  static double strengthAt(double fraction) {
    final u = fraction.clamp(0.0, 1.0);
    return 1 - u * u * (3 - 2 * u);
  }

  /// 自 [top] 到 [bottom] 按 [strengthAt] 把 [color] 淡到全透明的着色器。
  static ui.Shader _fadeShader(double top, double bottom, Color color) {
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i < _sampleCount; i++) {
      final fraction = i / (_sampleCount - 1);
      stops.add(fraction);
      colors.add(color.withValues(alpha: color.a * strengthAt(fraction)));
    }
    return ui.Gradient.linear(Offset(0, top), Offset(0, bottom), colors, stops);
  }

  /// 露出来的上缘在画布里的位置。
  double _visibleTop(Size size) {
    final visible = (visibleOverhang?.value ?? overhang).clamp(0.0, overhang);
    return (overhang - visible).clamp(0.0, size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final top = _visibleTop(size);
    // 没露出来的那截（在滚动视图之外）：不画底色；能擦时把模糊也擦掉，
    // 万一露出来也不会多出一块磨砂。
    if (top > 0 && eraseBackdrop) {
      canvas.drawRect(
        Rect.fromLTRB(0, 0, size.width, top),
        Paint()..blendMode = BlendMode.clear,
      );
    }
    if (top >= size.height) return;
    if (!fade) {
      canvas.drawRect(
        Rect.fromLTRB(0, top, size.width, size.height),
        Paint()..color = fill,
      );
      return;
    }
    // 上半截完整的底色，下半截渐变。
    final fadeTop = size.height - (size.height - top) * fadeFraction;
    canvas.drawRect(
      Rect.fromLTRB(0, top, size.width, fadeTop),
      Paint()..color = fill,
    );
    final rect = Rect.fromLTRB(0, fadeTop, size.width, size.height);
    if (eraseBackdrop) {
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          // dstIn 只看源的透明度，颜色取什么都一样。
          ..shader = _fadeShader(fadeTop, size.height, const Color(0xFF000000)),
      );
    }
    canvas.drawRect(
      rect,
      Paint()..shader = _fadeShader(fadeTop, size.height, fill),
    );
  }

  @override
  bool shouldRepaint(covariant GlassBottomFadePainter oldDelegate) =>
      oldDelegate.fade != fade ||
      oldDelegate.fill != fill ||
      oldDelegate.eraseBackdrop != eraseBackdrop ||
      oldDelegate.overhang != overhang ||
      oldDelegate.visibleOverhang != visibleOverhang;
}
