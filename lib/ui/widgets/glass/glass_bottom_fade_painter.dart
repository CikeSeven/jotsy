import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// 玻璃表面底缘渐隐：表面最下面 [extent] 高的一段里，玻璃自上而下淡出，
/// 到下缘时什么都不剩。由 `GlassSurface` 画在背景模糊图层之内、内容之前，
/// 代替原来均匀的底色。
///
/// 玻璃有两层，分两段淡出（都是两端斜率为 0 的 S 形曲线，见 [strengthAt]）：
/// - 底色：在整个渐隐区里由 [fill] 淡到全透明——“越往下越透明”主要是它；
/// - 背景模糊（连同饱和度增强）：只在渐隐区下面的 [blurFadeFraction] 里
///   淡出，上面保持完整。
///
/// 为什么不让两层一起淡：模糊的淡出是“模糊画面”与“清晰画面”的交叉淡化，
/// 淡到一半时下面的文字已经清晰可辨。顶栏的标题与按钮就排在渐隐区的上半
/// 截，两层一起淡的话，滚到栏下的文字会清清楚楚地叠在标题上（字压字）。
/// 模糊留到标题下沿以下再收，标题背后始终是一片磨砂，只是底色越来越薄；
/// 最后一小段模糊淡完，下缘与页面无缝衔接、没有一条硬边。
///
/// 模糊怎么淡出（[eraseBackdrop]）：背景模糊会开一个离屏图层，图层的初始
/// 内容是“模糊后的背景”。这里用 [BlendMode.dstIn] 画一块自上而下由不透明
/// 到透明的矩形，图层里已有的像素就按这条透明度曲线被擦除；图层合成回
/// 页面时，擦掉的部分露出下方没有模糊的页面。所以必须先擦、后画底色
/// （否则底色也被擦一遍，两段曲线就乘在一起了）。
///
/// 为什么不用别的办法：
/// - 把玻璃放进 `ShaderMask` / `Opacity`：模糊只能采到遮罩图层自己（空的），
///   整块玻璃会失去模糊（`GlassSurface` 的约束同理）；
/// - 叠几条模糊半径递减的 `BackdropFilter`：每条都多一轮背景模糊，还看得出
///   分段。这里只多两次矩形绘制，不多任何图层与模糊。
///
/// 没有离屏图层时（模糊关闭）[eraseBackdrop] 必须为 false：dstIn 会直接
/// 擦掉当前画布上的页面内容。
///
/// 两块渐变都是同一种颜色只变透明度（其中一块连颜色都不起作用），是遮罩
/// 而不是配色，属于“界面不用渐变色”之外的例外（DESIGN.md §2.2）。
class GlassBottomFadePainter extends CustomPainter {
  const GlassBottomFadePainter({
    required this.extent,
    required this.fill,
    required this.eraseBackdrop,
    this.trailing,
  }) : assert(extent > 0),
       super(repaint: trailing);

  /// 渐隐区的高度，从整条栏的下缘（表面下缘再往下 [trailing]）往上量。
  final double extent;

  /// 表面下缘之下、同属一条栏的玻璃还有多高（见
  /// `GlassSurface.bottomFadeTrailing`）；null 即 0，表面自己的下缘就是栏的
  /// 下缘。它在布局阶段变化（下面那片玻璃量出自己的高度），这里只需要重画，
  /// 所以直接作为画笔的 repaint 监听，不经过重建。
  final ValueListenable<double>? trailing;

  /// 渐隐区之上的底色（已带透明度）；渐隐区内由它淡到全透明。
  final Color fill;

  /// 是否把渐隐区下段的背景模糊擦淡；只有画在已启用的 `BackdropFilter`
  /// 之内才能为 true。
  final bool eraseBackdrop;

  /// 背景模糊在渐隐区最下面的这一部分里淡出。取三分之一：48 高的渐隐区里
  /// 是最下面 16——顶栏标题（含下伸笔画）与按钮图标的下沿都在它之上，
  /// 标题背后的模糊是完整的；16 也足够让模糊的边界化开、看不出一条线。
  static const double blurFadeFraction = 1 / 3;

  /// 透明度曲线的采样点数（含两端）。线性渐变在两个采样点之间是直线，
  /// 9 个点足够贴近 [strengthAt] 的 S 形，肉眼看不出折线。
  static const int _sampleCount = 9;

  /// 一段淡出里自上（0）而下（1）的强度：1 − smoothstep。两端的斜率都是
  /// 0——上端与完整的玻璃平滑相接，看不出淡出从哪一行开始；下端贴着 0
  /// 收尾，下缘不留一条线。
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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // 两段都按整条栏的下缘对齐，只画落在本表面之内的那一截：
    // - 表面比渐隐区矮：起点落在表面之上，从曲线的半途开始画；
    // - 下面还接着一片玻璃（trailing > 0）：终点落在表面之下，曲线的后半截
    //   由那一片接着画——两片用的是同一条曲线的同一组坐标，接缝处连续。
    final bottom = size.height + math.max(0.0, trailing?.value ?? 0);
    final blurTop = bottom - extent * blurFadeFraction;
    if (eraseBackdrop && blurTop < size.height) {
      canvas.drawRect(
        Rect.fromLTRB(0, math.max(0, blurTop), size.width, size.height),
        Paint()
          ..blendMode = BlendMode.dstIn
          // dstIn 只看源的透明度，颜色取什么都一样。
          ..shader = _fadeShader(blurTop, bottom, const Color(0xFF000000)),
      );
    }
    final fillTop = math.min(bottom - extent, size.height);
    if (fillTop > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, 0, size.width, fillTop),
        Paint()..color = fill,
      );
    }
    if (fillTop < size.height) {
      canvas.drawRect(
        Rect.fromLTRB(0, math.max(0, fillTop), size.width, size.height),
        Paint()..shader = _fadeShader(bottom - extent, bottom, fill),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GlassBottomFadePainter oldDelegate) =>
      oldDelegate.extent != extent ||
      oldDelegate.fill != fill ||
      oldDelegate.eraseBackdrop != eraseBackdrop ||
      oldDelegate.trailing != trailing;
}
