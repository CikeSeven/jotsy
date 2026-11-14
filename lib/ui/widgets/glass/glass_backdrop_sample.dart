import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'glass_backdrop_blur_cache.dart';

export 'glass_backdrop_blur_cache.dart';

/// Leader 的实际尺寸变化时只通知取样画笔重绘。卡片自身尺寸可能没变（例如
/// 桌面窗口只改变高度），不能仅靠 CustomPaint 的重新布局更新 cover 取景。
class GlassBackdropLink extends LayerLink with ChangeNotifier {
  bool _disposed = false;

  @override
  set leaderSize(Size? value) {
    if (value == super.leaderSize) return;
    super.leaderSize = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 内容玻璃的背景取样：用一张预先模糊好的页面背景代替逐帧的背景模糊。
///
/// 为什么：内容玻璃（卡片、分组、日历卡）只模糊页面背景——同一页里共用
/// 一次背景读取，读取发生在第一块玻璃画之前，之后画的内容本就不进模糊
/// （见 `AppPageBackdrop.contentBackdropKey`）。但 `BackdropFilter` 仍要
/// 每帧回读整屏、再对整片区域做高斯模糊；真机上滑动日历、探索时这一项单独
/// 就让约 10% 的帧光栅超出 120Hz 预算，尤其集中在静止后刚开始滑的几帧。
/// 页面背景是静止的图（随页面平移的只有内容），模糊结果在背景、尺寸与
/// 参数不变时恒定，所以只需算一次：
///
/// - 背景层外面包一个 [CompositedTransformTarget]（[link] 的 Leader）；
/// - 玻璃在自己的圆角裁切里放一个 [CompositedTransformFollower]，把预模糊图
///   画在 Leader 的坐标系里、铺满 Leader。Follower 的变换在每帧合成时按
///   Leader 的实际位置重新计算，内容滚动、首页翻页、越界拉伸时取样区域都
///   与背景对齐，卡片本身不必重绘；截图（`toImageSync`）时同样沿主树算出
///   相对位置，截到的也是正确的那一块；
/// - 遮罩是一层均匀颜色，模糊与饱和度都是线性运算：先模糊背景、再叠遮罩，
///   与模糊“背景 + 遮罩”的结果相同，生成缓存时一起叠上 [scrim]。
///   只在背景已落定且由背景自己画遮罩时使用；背景交叉淡入、区域间背景
///   不同或页面按基调染色遮罩时保留实时模糊。
///
/// 输入：背景图句柄（不归本类所有）、cover 对齐、图下垫的页面底色、遮罩；
/// 按值比较，背景换图、改焦点或遮罩时通知依赖者重建。
@immutable
class GlassBackdropSample {
  const GlassBackdropSample({
    required this.link,
    required this.image,
    required this.alignment,
    required this.underColor,
    this.scrim,
  });

  /// 背景层上 [CompositedTransformTarget] 的链接。
  final GlassBackdropLink link;

  /// 背景层画的图（`BoxFit.cover` 铺满 Leader）。
  final ui.Image image;

  /// cover 时的焦点，与背景层的 `RawImage.alignment` 相同。
  final Alignment alignment;

  /// 背景层在图下垫的颜色（带透明区域的图会透出它）。
  final Color underColor;

  /// 叠在背景上的遮罩；null 表示没有。
  final Color? scrim;

  @override
  bool operator ==(Object other) =>
      other is GlassBackdropSample &&
      identical(other.link, link) &&
      other.image.isCloneOf(image) &&
      other.alignment == alignment &&
      other.underColor == underColor &&
      other.scrim == scrim;

  @override
  int get hashCode => Object.hash(
    link,
    image.width,
    image.height,
    alignment,
    underColor,
    scrim,
  );
}

/// 把 [sample] 的预模糊背景画在 Leader 坐标系里，由外层的圆角裁切截出玻璃
/// 下面的那一块。
///
/// 放在玻璃的裁切之内、底色之下；[opacity] 对应玻璃的淡入进度（模糊半径
/// 不随进度变：逐帧换半径会逐帧重新生成预模糊图）。Leader 不在时（背景
/// 还没画出来）什么也不画。不接收点按。
class GlassBackdropSampleView extends StatelessWidget {
  const GlassBackdropSampleView({
    super.key,
    required this.sample,
    required this.sigma,
    this.saturation = 1,
    this.opacity = 1,
  });

  final GlassBackdropSample sample;
  final double sigma;
  final double saturation;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CompositedTransformFollower(
        link: sample.link,
        showWhenUnlinked: false,
        child: CustomPaint(
          painter: _GlassBackdropSamplePainter(
            sample: sample,
            sigma: sigma,
            saturation: saturation,
            opacity: opacity,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _GlassBackdropSamplePainter extends CustomPainter {
  _GlassBackdropSamplePainter({
    required this.sample,
    required this.sigma,
    required this.saturation,
    required this.opacity,
  }) : super(repaint: sample.link);

  final GlassBackdropSample sample;
  final double sigma;
  final double saturation;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    // 本组件按玻璃自己的大小布局，但画的是整块 Leader：Follower 把坐标系
    // 换成了 Leader 的，外层裁切只留玻璃下面那一块。
    final leaderSize = sample.link.leaderSize;
    if (leaderSize == null || leaderSize.isEmpty || opacity <= 0) {
      return;
    }
    final blurred = GlassBackdropBlurCache.resolve(
      sample: sample,
      size: leaderSize,
      sigma: sigma,
      saturation: saturation,
    );
    if (blurred == null) {
      return;
    }
    final dst = Offset.zero & leaderSize;
    canvas.drawImageRect(
      blurred,
      Offset.zero & Size(blurred.width.toDouble(), blurred.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(_GlassBackdropSamplePainter oldDelegate) =>
      oldDelegate.sample != sample ||
      oldDelegate.sigma != sigma ||
      oldDelegate.saturation != saturation ||
      oldDelegate.opacity != opacity;
}
