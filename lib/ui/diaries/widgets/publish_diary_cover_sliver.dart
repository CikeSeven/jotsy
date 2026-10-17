import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/expressive_image_frame.dart';
import '../../widgets/image_viewer_hero.dart';
import '../../widgets/long_image/long_image_policy.dart';
import 'diary_image_source.dart';

/// 发布页头图 Sliver。
///
/// 提供“上滑逐渐淡出 + 高度收起”的视觉效果。设置 [heroTag] 后封面画面是
/// 共享元素：既是从列表封面飞入的落点，也是点按打开看图页的起点（点按时
/// [onTap] 收到从画面抓取的飞入信息）。
class PublishDiaryCoverSliver extends StatelessWidget {
  const PublishDiaryCoverSliver({
    super.key,
    required this.cover,
    this.maxExtentHeight = 220,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.heroTag,
    this.placeholder,
    this.onTap,
    this.reveal = 1,
    this.background,
    this.fillFrame = false,
    this.collapseEffect = true,
  });

  final String cover;
  final double maxExtentHeight;

  /// 插入/移除过渡进度（0~1，见 AnimatedPublishDiaryCoverSliver）：可见高度与
  /// 不透明度按此比例缩放；解码尺寸仍按 [maxExtentHeight]，过渡期间不会因
  /// 缓存键变化逐帧重新解码。
  final double reveal;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;

  /// 共享元素标签；为 null 时不建立 Hero。
  final Object? heroTag;

  /// 入口（列表封面）已解码的画面：首帧即知原图比例，飞入落点准确；原图解码
  /// 完成前垫在下面，避免先空白再淡入。所有权归调用方。
  final ui.Image? placeholder;

  /// 点按封面；参数为飞入看图页所需信息，未设 [heroTag]、图片未解码或减少
  /// 动画时为 null。
  final ValueChanged<ImageViewerHero?>? onTap;

  /// 头图框底色（原图比例与框不同时露出的部分）；默认为主题 surface。
  final Color? background;

  /// 铺满头图框并裁掉超出部分；默认完整显示原图（框内按原图比例居中）。
  final bool fillFrame;

  /// 上滑收起时淡出并轻微缩小；关闭后头图随页面平移、保持不透明。
  final bool collapseEffect;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: false,
      delegate: _PublishDiaryCoverHeaderDelegate(
        cover: cover,
        maxExtentHeight: maxExtentHeight,
        padding: padding,
        borderRadius: borderRadius,
        heroTag: heroTag,
        placeholder: placeholder,
        onTap: onTap,
        reveal: reveal,
        background: background,
        fillFrame: fillFrame,
        collapseEffect: collapseEffect,
      ),
    );
  }
}

class _PublishDiaryCoverHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PublishDiaryCoverHeaderDelegate({
    required this.cover,
    required this.maxExtentHeight,
    required this.padding,
    required this.borderRadius,
    required this.heroTag,
    required this.placeholder,
    required this.onTap,
    required this.reveal,
    required this.background,
    required this.fillFrame,
    required this.collapseEffect,
  });
  final String cover;
  final double maxExtentHeight;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Object? heroTag;
  final ui.Image? placeholder;
  final ValueChanged<ImageViewerHero?>? onTap;
  final double reveal;
  final Color? background;
  final bool fillFrame;
  final bool collapseEffect;

  @override
  double get minExtent => 0;

  @override
  double get maxExtent => maxExtentHeight * reveal;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // 计算 0~1 收起进度，用于统一驱动透明度与缩放。
    final extentDelta = (maxExtent - minExtent).abs();
    final collapseProgress = !collapseEffect
        ? 1.0
        : extentDelta <= 0
        ? 0.0
        : (1 - (shrinkOffset / extentDelta)).clamp(0.0, 1.0).toDouble();

    // 透明度直接作用在图片绘制上，而不是外包 Opacity：滚动收起期间不透明度
    // 逐帧为小数，Opacity 会每帧为整块封面 saveLayer。底色与页面同为
    // surface，是否随之淡出在视觉上没有差别。
    final coverContent = _CoverTapTarget(
      onTap: onTap,
      heroTag: heroTag,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background ?? Theme.of(context).colorScheme.surface,
        ),
        child: _CoverImage(
          cover: cover,
          fillFrame: fillFrame,
          opacity: collapseProgress * reveal,
          decodeHeight: maxExtentHeight,
          heroTag: heroTag,
          borderRadius: borderRadius.resolve(Directionality.of(context)),
          placeholder: placeholder,
        ),
      ),
    );
    return Padding(
      padding: padding,
      child: Transform.scale(
        // 收起阶段同时轻微缩放，降低突兀感。
        scale: 0.96 + (collapseProgress * 0.04),
        alignment: Alignment.topCenter,
        child: borderRadius == BorderRadius.zero
            ? coverContent
            : ClipRRect(borderRadius: borderRadius, child: coverContent),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PublishDiaryCoverHeaderDelegate oldDelegate) {
    return oldDelegate.cover != cover ||
        oldDelegate.maxExtentHeight != maxExtentHeight ||
        oldDelegate.reveal != reveal ||
        oldDelegate.padding != padding ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.heroTag != heroTag ||
        oldDelegate.placeholder != placeholder ||
        oldDelegate.onTap != onTap ||
        oldDelegate.background != background ||
        oldDelegate.fillFrame != fillFrame ||
        oldDelegate.collapseEffect != collapseEffect;
  }
}

class _CoverTapTarget extends StatelessWidget {
  const _CoverTapTarget({
    required this.onTap,
    required this.heroTag,
    required this.child,
  });

  final ValueChanged<ImageViewerHero?>? onTap;
  final Object? heroTag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final handler = onTap;
    if (handler == null) {
      return child;
    }
    final tag = heroTag;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 点按瞬间从封面画面抓取飞入信息：此刻画面一定是用户看到的那一张。
      onTap: () => handler(
        tag == null ? null : ImageViewerHero.capture(context, tag: tag),
      ),
      child: child,
    );
  }
}

class _CoverImage extends StatefulWidget {
  const _CoverImage({
    required this.cover,
    required this.fillFrame,
    required this.opacity,
    required this.decodeHeight,
    required this.heroTag,
    required this.borderRadius,
    required this.placeholder,
  });

  final String cover;
  final bool fillFrame;
  final double opacity;

  /// 解码高度上界：取头部最大高度而非当前约束。收起过程中约束高度逐帧
  /// 变化，若参与 ResizeImage 的缓存键，会导致滚动时每帧重新解码。
  final double decodeHeight;
  final Object? heroTag;
  final BorderRadius borderRadius;
  final ui.Image? placeholder;

  @override
  State<_CoverImage> createState() => _CoverImageState();
}

/// 封面完整展示原图（视觉等同 BoxFit.contain），但画面不再铺满整个头部：
/// 按原图比例取一个居中的盒子，图片以 cover 铺满盒子——比例一致所以不裁切。
/// 这样共享元素的边界就是画面本身，飞入看图页时不会从“留边的头部”跳成全图。
/// 比例在图片首次解码时从图片流读取；解码前或加载失败时盒子铺满头部，失败
/// 占位与此前一致。
class _CoverImageState extends State<_CoverImage> {
  ImageProvider? _listenedProvider;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    _handleImage,
    onError: (Object error, StackTrace? stackTrace) {},
  );
  late double? _aspectRatio = _placeholderAspectRatio(widget.placeholder);

  static double? _placeholderAspectRatio(ui.Image? image) =>
      image == null || image.height == 0 ? null : image.width / image.height;

  /// 构建期间解析图片流：缓存命中时监听器会在 addListener 内同步回调，此时
  /// 直接写入比例供本次构建使用，不能 setState。
  bool _resolvingInBuild = false;

  void _listenTo(ImageProvider provider) {
    if (provider == _listenedProvider) {
      return;
    }
    _stream?.removeListener(_listener);
    _listenedProvider = provider;
    _resolvingInBuild = true;
    _stream = provider.resolve(createLocalImageConfiguration(context))
      ..addListener(_listener);
    _resolvingInBuild = false;
  }

  void _handleImage(ImageInfo info, bool synchronousCall) {
    final image = info.image;
    final ratio = image.height == 0 ? null : image.width / image.height;
    info.dispose();
    if (ratio == null || !ratio.isFinite || ratio == _aspectRatio) {
      return;
    }
    if (_resolvingInBuild || !mounted) {
      _aspectRatio = ratio;
      return;
    }
    setState(() => _aspectRatio = ratio);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 解码按可见区域等比缩小（ResizeImagePolicy.fit，小图不放大），避免把
    // 数千像素的原图整张解码进内存；fit 策略保持原图比例，不会拉伸变形。
    // 长图铺满头部时 cover 只取顶部一段：若仍按“宽、高都不超过头部”解码，
    // 整条长图会缩成几十像素宽再被放大，所以改为只按宽度解码并顶部对齐。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final source = diaryImageProvider(widget.cover);
        final ratio = _aspectRatio;
        final long =
            widget.fillFrame &&
            ratio != null &&
            ratio > 0 &&
            isLongImageSize(Size(ratio, 1));
        final provider = !constraints.hasBoundedWidth
            ? boundedImageProvider(source)
            : long
            ? boundedImageProvider(
                source,
                width: (constraints.maxWidth * dpr).round(),
              )
            : ResizeImage(
                source,
                width: (constraints.maxWidth * dpr).round(),
                height: (widget.decodeHeight * dpr).round(),
                policy: ResizeImagePolicy.fit,
              );
        final alignment = long ? Alignment.topCenter : Alignment.center;
        _listenTo(provider);
        // 加载淡入与滚动收起的渐隐各走一路：前者在 frameBuilder 里只持续一次
        // 解码完成的 180ms，之后不透明度恒为 1、不产生离屏层；后者仍直接作用在
        // Image.opacity 上，滚动期间不额外 saveLayer。
        final image = Image(
          image: provider,
          fit: BoxFit.cover,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          opacity: AlwaysStoppedAnimation<double>(widget.opacity),
          frameBuilder: expressiveImageFrameBuilder,
          errorBuilder: (_, __, ___) => const _CoverFallback(),
        );
        final boxRatio =
            _aspectRatio ??
            (constraints.maxHeight > 0 && constraints.maxWidth.isFinite
                ? constraints.maxWidth / constraints.maxHeight
                : 1.0);
        final placeholder = widget.placeholder;
        final framed = ImageViewerHeroSource(
          tag: widget.heroTag,
          borderRadius: widget.borderRadius,
          // 入口画面垫底：原图解码完成后淡入覆盖它（同一缓存键的原图已在
          // 缓存时直接显示），飞入落地后不会先空白。
          child: placeholder == null
              ? image
              : Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    RawImage(
                      image: placeholder,
                      fit: BoxFit.cover,
                      alignment: alignment,
                      opacity: AlwaysStoppedAnimation<double>(widget.opacity),
                    ),
                    image,
                  ],
                ),
        );
        if (widget.fillFrame) {
          return framed;
        }
        return Center(
          child: AspectRatio(aspectRatio: boxRatio, child: framed),
        );
      },
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          context.l10n.autoT0156,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
