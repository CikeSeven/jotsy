import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/app_platform.dart';
import '../../diaries/widgets/diary_image_source.dart';
import '../../widgets/expressive_image_frame.dart';
import '../../widgets/image_viewer_hero.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../models/explore_view_data.dart';

/// 画廊一格被点按 / 长按时的回调：整体下标与格子自己的 context（看图页从
/// 它抓取已绘制的缩略图作为飞入画面）。
typedef GalleryCellTap = void Function(int index, BuildContext cellContext);

/// 正式网格里每张图正在显示的画面（按来源）：换档过渡直接拿来画，不再
/// 读文件、不再解码。由格子在拿到 / 换掉 / 卸载画面时登记与注销。
class GalleryLiveImages {
  final Map<String, ui.Image> _images = <String, ui.Image>{};

  ui.Image? operator [](String source) => _images[source];

  void _put(String source, ui.Image image) => _images[source] = image;

  void _remove(String source, ui.Image image) {
    if (identical(_images[source], image)) _images.remove(source);
  }
}

/// 网格里的一行格子：从整体下标 [first] 起的 [count] 张，每格 [extent]
/// 见方、间隔 [gap]，左右留 [padding]。
///
/// 一屏可能有几百格（16 列），这里刻意保持轻量：点按与长按整行一个手势，
/// 按位置换算是哪一格；每格只有一个画面组件（见 [GalleryCell]）。
/// [interactive] 为 false 时不挂手势、不登记画面。
class GalleryCellRow extends StatelessWidget {
  const GalleryCellRow({
    super.key,
    required this.items,
    required this.first,
    required this.count,
    required this.extent,
    required this.gap,
    required this.padding,
    required this.radius,
    required this.decodeExtent,
    required this.interactive,
    this.fallbackExtent,
    this.liveImages,
    this.heroTagOf,
    this.onTap,
    this.onLongPress,
  });

  /// 格子小于它时不做看图页的共享元素（16 列时一屏几百个 Hero，飞行也
  /// 看不出来）。
  static const double heroMinExtent = 40;

  final List<ExploreMediaItem> items;
  final int first;
  final int count;
  final double extent;
  final double gap;
  final double padding;
  final double radius;

  /// 解码边长（物理像素），见 `GalleryZoom.decodeReference`。
  final int decodeExtent;

  /// 另一族档位的解码边长：自己的还没解码好时先显示缓存里的那一份。
  final int? fallbackExtent;
  final bool interactive;
  final GalleryLiveImages? liveImages;
  final Object Function(String source)? heroTagOf;
  final GalleryCellTap? onTap;
  final ValueChanged<int>? onLongPress;

  @override
  Widget build(BuildContext context) {
    final placeholder = Theme.of(context).colorScheme.surfaceContainer;
    final hero = interactive && extent >= heroMinExtent;
    final tap = onTap;
    final children = <Widget>[];
    for (var i = 0; i < count; i++) {
      if (i > 0) children.add(SizedBox(width: gap));
      final index = first + i;
      final source = items[index].source;
      children.add(
        GalleryCell(
          source: source,
          extent: extent,
          decodeExtent: decodeExtent,
          fallbackExtent: fallbackExtent,
          radius: radius,
          placeholder: placeholder,
          liveImages: interactive ? liveImages : null,
          heroTag: hero ? heroTagOf?.call(source) : null,
          onSemanticTap: interactive && tap != null
              ? (BuildContext cellContext) => tap(index, cellContext)
              : null,
        ),
      );
    }
    final Widget row = Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
    if (!interactive) return row;
    final detector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: tap == null
          ? null
          : (TapUpDetails details) {
              final index = _indexAt(details.localPosition);
              if (index != null) tap(index, _cellContext(context, index));
            },
      onLongPressStart: onLongPress == null
          ? null
          : (LongPressStartDetails details) {
              final index = _indexAt(details.localPosition);
              if (index != null) onLongPress!(index);
            },
      child: row,
    );
    // 桌面上指针悬停显示为可点（手机上没有指针，不多挂一层）。
    return AppPlatform.isDesktop
        ? MouseRegion(cursor: SystemMouseCursors.click, child: detector)
        : detector;
  }

  /// 行内位置 [position] 落在哪一格（落在间隔或行末空白处为 null）。
  int? _indexAt(Offset position) {
    final x = position.dx - padding;
    final stride = extent + gap;
    if (x < 0 || stride <= 0) return null;
    final column = x ~/ stride;
    if (column >= count || x - column * stride > extent) return null;
    return first + column;
  }

  /// 第 [index] 张那一格的 context（找不到时退回整行）。
  BuildContext _cellContext(BuildContext context, int index) {
    final source = items[index].source;
    BuildContext? found;
    void visit(Element element) {
      if (found != null) return;
      final widget = element.widget;
      if (widget is GalleryCell && widget.source == source) {
        found = element;
        return;
      }
      element.visitChildElements(visit);
    }

    (context as Element).visitChildElements(visit);
    return found ?? context;
  }
}

/// 一格缩略图：按 [decodeExtent] 等比铺满解码（长图顶部对齐）。
///
/// 只有一个画面组件（[RawImage]），自己监听图片流：
/// - 缓存命中时直接显示；否则先找另一族档位解码好的那一份（[fallbackExtent]，
///   换档后格子变大 / 变小时），有就先显示它、等自己的到了再换，不闪空白；
///   都没有时显示占位底色，解码出来后淡入（同 [expressiveImageFrameBuilder]）；
/// - 快速滚动时与 [Image] 一样推迟解码（[ScrollAwareImageProvider]）；
/// - 拿到画面后登记到 [liveImages]，换档过渡直接取用。
class GalleryCell extends StatefulWidget {
  const GalleryCell({
    super.key,
    required this.source,
    required this.extent,
    required this.decodeExtent,
    required this.radius,
    required this.placeholder,
    this.fallbackExtent,
    this.liveImages,
    this.heroTag,
    this.onSemanticTap,
  });

  final String source;
  final double extent;
  final int decodeExtent;
  final int? fallbackExtent;
  final double radius;
  final Color placeholder;
  final GalleryLiveImages? liveImages;
  final Object? heroTag;

  /// 读屏的“点按”（手势由整行处理）。
  final ValueChanged<BuildContext>? onSemanticTap;

  @override
  State<GalleryCell> createState() => _GalleryCellState();
}

class _GalleryCellState extends State<GalleryCell> {
  late final DisposableBuildContext<State<GalleryCell>> _scrollContext =
      DisposableBuildContext<State<GalleryCell>>(this);
  late final ImageStreamListener _listener = ImageStreamListener(
    _handleImage,
    onError: (Object _, StackTrace? _) {},
  );
  late final ImageStreamListener _fallbackListener = ImageStreamListener(
    _handleFallback,
    onError: (Object _, StackTrace? _) {},
  );

  ImageProvider? _provider;
  ImageStream? _stream;
  ImageInfo? _info;

  /// [_info] 登记在哪个表、哪个来源下（格子换了图时 widget 已是新的，注销
  /// 要用登记时的值）。
  GalleryLiveImages? _registry;
  String? _registeredSource;
  ImageStream? _fallbackStream;
  ImageInfo? _fallback;

  /// 正在 [_resolve] 里同步拿到画面（此时在构建阶段，不能 setState）。
  bool _resolving = false;

  /// 这张图第一次露面时已有画面（缓存命中或先用了另一份），不做淡入。
  bool _instant = false;

  ImageProvider _providerFor(int extent) => boundedImageProvider(
    diaryImageProvider(widget.source),
    width: extent,
    height: extent,
    cover: true,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(GalleryCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.decodeExtent != widget.decodeExtent) {
      _resolve(sourceChanged: oldWidget.source != widget.source);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _dropFallback();
    _releaseInfo(_info);
    _scrollContext.dispose();
    super.dispose();
  }

  void _resolve({bool sourceChanged = false}) {
    final provider = _providerFor(widget.decodeExtent);
    if (provider == _provider) return;
    _provider = provider;
    _stream?.removeListener(_listener);
    final previous = _info;
    _info = null;
    if (sourceChanged) {
      _dropFallback();
      _releaseInfo(previous);
    } else if (previous != null) {
      // 同一张图换了解码尺寸（换档）：旧画面留作过渡，等新的到了再换。
      _dropFallback();
      _unregister(previous);
      _fallback = previous;
    }
    final configuration = createLocalImageConfiguration(context);
    final stream = ScrollAwareImageProvider<Object>(
      context: _scrollContext,
      imageProvider: provider,
    ).resolve(configuration);
    _stream = stream;
    _resolving = true;
    stream.addListener(_listener);
    _resolving = false;
    if (_info == null && _fallback == null) _useCachedFallback(configuration);
    _instant = _info != null || _fallback != null;
  }

  /// 自己的尺寸还没有：缓存里有另一族档位解码好的这张图就先用它。键的
  /// 计算是同步的（本地文件 / 等比解码的 provider），没有命中时不发起加载。
  void _useCachedFallback(ImageConfiguration configuration) {
    final extent = widget.fallbackExtent;
    if (extent == null || extent == widget.decodeExtent) return;
    final provider = _providerFor(extent);
    Object? key;
    provider.obtainKey(configuration).then((Object value) => key = value);
    final cacheKey = key;
    if (cacheKey == null ||
        !PaintingBinding.instance.imageCache.containsKey(cacheKey)) {
      return;
    }
    final stream = provider.resolve(configuration);
    _fallbackStream = stream;
    _resolving = true;
    stream.addListener(_fallbackListener);
    _resolving = false;
  }

  void _handleImage(ImageInfo info, bool synchronousCall) {
    final previous = _info;
    _releaseInfo(previous);
    _info = info;
    final registry = widget.liveImages;
    if (registry != null) {
      registry._put(widget.source, info.image);
      _registry = registry;
      _registeredSource = widget.source;
    }
    _dropFallback();
    if (!_resolving && mounted) setState(() {});
  }

  void _handleFallback(ImageInfo info, bool synchronousCall) {
    if (_info != null) {
      info.dispose();
      return;
    }
    _fallback?.dispose();
    _fallback = info;
    if (!_resolving && mounted) setState(() {});
  }

  void _dropFallback() {
    _fallbackStream?.removeListener(_fallbackListener);
    _fallbackStream = null;
    _fallback?.dispose();
    _fallback = null;
  }

  void _releaseInfo(ImageInfo? info) {
    if (info == null) return;
    _unregister(info);
    info.dispose();
  }

  void _unregister(ImageInfo info) {
    final source = _registeredSource;
    if (source != null) _registry?._remove(source, info.image);
    _registry = null;
    _registeredSource = null;
  }

  @override
  Widget build(BuildContext context) {
    final image = (_info ?? _fallback)?.image;
    final long =
        image != null &&
        isLongImageSize(Size(image.width.toDouble(), image.height.toDouble()));
    Widget picture = RawImage(
      image: image,
      width: widget.extent,
      height: widget.extent,
      fit: BoxFit.cover,
      alignment: long ? Alignment.topCenter : Alignment.center,
      filterQuality: FilterQuality.low,
    );
    picture = expressiveImageFrameBuilder(
      context,
      picture,
      image == null ? null : 0,
      _instant,
    );
    picture = ColoredBox(color: widget.placeholder, child: picture);
    final borderRadius = BorderRadius.circular(widget.radius);
    if (widget.radius > 0) {
      picture = ClipRRect(borderRadius: borderRadius, child: picture);
    }
    final tag = widget.heroTag;
    if (tag != null) {
      picture = ImageViewerHeroSource(
        tag: tag,
        borderRadius: borderRadius,
        child: picture,
      );
    }
    final semanticTap = widget.onSemanticTap;
    return SizedBox(
      width: widget.extent,
      height: widget.extent,
      child: semanticTap == null
          ? picture
          : Semantics(
              button: true,
              image: true,
              onTap: () => semanticTap(context),
              child: picture,
            ),
    );
  }
}
