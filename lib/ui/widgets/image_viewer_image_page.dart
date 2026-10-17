import 'package:flutter/material.dart';
import 'package:node_diary/core/services/long_image_tile_service.dart';
import 'package:node_diary/ui/widgets/double_tap_zoom_viewer.dart';
import 'package:node_diary/ui/widgets/image_viewer_full_image.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_source_builder.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_tiles_view.dart';

/// 看图页的一页：按图片比例选择普通显示或长图模式。
///
/// - 普通图：整张 contain 居中，双击/捏合缩放（[DoubleTapZoomViewer]）；
/// - 长图（高 ≥ 宽 × 3，且按屏宽铺满后比视口高）：宽度铺满、从顶部开始，
///   拖动上下滚动，双击在原始大小与 2.5 倍之间切换；只解码可见范围上下各
///   一屏内的分片（[LongImageTilesView]）。长图整张 contain 只剩一条细线，
///   放大到上限也读不清文字，所以不走普通模式。
///
/// 初始页带共享元素 [hero] 时：普通图沿用原图比例盒子（[ImageViewerHeroTarget]）；
/// 长图的 Hero 包住整个视口，飞行中显示的就是“按屏宽从顶部开始”的画面，与正文
/// 折叠盒子露出的顶部一致。放大或已离开顶部时关闭 Hero，返回只淡出。
///
/// 尺寸经 [LongImageSourceBuilder] 读取；正文显示过的图已缓存，首帧即可判定。
/// 未缓存时若来源画面本身是长图比例（探索页缩略图解码的是整张图）先按长图
/// 显示，否则先按普通图显示，读出尺寸后再校正。
///
/// 输出：[onZoomChanged] 报告放大态（宿主据此锁定翻页与下拉关闭）；
/// [onTallChanged] 报告是否处于长图模式（竖向拖动用于滚动，宿主应关闭下拉
/// 关闭）。
class ImageViewerImagePage extends StatefulWidget {
  const ImageViewerImagePage({
    super.key,
    required this.source,
    this.hero,
    required this.onZoomChanged,
    required this.onTallChanged,
  });

  final String source;
  final ImageViewerHero? hero;
  final ValueChanged<bool> onZoomChanged;
  final ValueChanged<bool> onTallChanged;

  @override
  State<ImageViewerImagePage> createState() => _ImageViewerImagePageState();
}

class _ImageViewerImagePageState extends State<ImageViewerImagePage> {
  bool _zoomed = false;
  bool _scrolled = false;
  bool? _reportedTall;

  void _handleZoomChanged(bool zoomed) {
    if (mounted && zoomed != _zoomed) {
      setState(() => _zoomed = zoomed);
    }
    widget.onZoomChanged(zoomed);
  }

  void _handleScrolledChanged(bool scrolled) {
    if (mounted && scrolled != _scrolled) {
      setState(() => _scrolled = scrolled);
    }
  }

  /// 长图模式在布局时才能判定（要比较视口比例），在帧后通知宿主。
  void _reportTall(bool tall) {
    if (_reportedTall == tall) {
      return;
    }
    _reportedTall = tall;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _reportedTall == tall) {
        widget.onTallChanged(tall);
      }
    });
  }

  /// 长图的高宽比；不是长图（或尚不知道）时为 null。
  double? _tallFactor(LongImageSnapshot snapshot) {
    final size = snapshot.size;
    if (snapshot.sizeResolved) {
      return size != null && snapshot.isLong ? size.height / size.width : null;
    }
    final hero = widget.hero;
    if (hero != null &&
        isLongImageSize(
          Size(
            hero.placeholder.width.toDouble(),
            hero.placeholder.height.toDouble(),
          ),
        )) {
      return 1 / hero.aspectRatio;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LongImageSourceBuilder(
      source: widget.source,
      builder: (BuildContext context, LongImageSnapshot snapshot) {
        final factor = _tallFactor(snapshot);
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final viewport = constraints.biggest;
            final tall =
                factor != null && viewport.width * factor > viewport.height;
            _reportTall(tall);
            return tall
                ? _buildTall(context, factor, snapshot.tiles, viewport)
                : _buildNormal();
          },
        );
      },
    );
  }

  Widget _buildNormal() {
    final hero = widget.hero;
    if (hero == null) {
      return DoubleTapZoomViewer(
        onZoomChanged: _handleZoomChanged,
        child: Center(
          child: ImageViewerFullImage(
            source: widget.source,
            fit: BoxFit.contain,
            placeholderBehind: false,
          ),
        ),
      );
    }
    // 放大后返回不做飞行（放大的画面飞回缩略图会先猛地缩一大截），只淡出。
    return DoubleTapZoomViewer(
      onZoomChanged: _handleZoomChanged,
      child: HeroMode(
        enabled: !_zoomed,
        child: ImageViewerHeroTarget(
          hero: hero,
          fullImage: ImageViewerFullImage(
            source: widget.source,
            fit: BoxFit.cover,
            placeholderBehind: true,
          ),
        ),
      ),
    );
  }

  Widget _buildTall(
    BuildContext context,
    double factor,
    LongImageTiles? tiles,
    Size viewport,
  ) {
    final hero = widget.hero;
    // 放大到上限时仍有足够像素：按两倍视口宽解码，原图更窄时不放大。
    final decodeWidth =
        (viewport.width * MediaQuery.devicePixelRatioOf(context) * 2).ceil();
    final placeholder = hero != null && _placeholderFits(hero, tiles)
        ? hero.placeholder
        : null;
    Widget viewer = DoubleTapZoomViewer.tall(
      contentHeightFactor: factor,
      onZoomChanged: _handleZoomChanged,
      onScrolledChanged: _handleScrolledChanged,
      builder: (BuildContext context, Size contentSize, Rect visible) {
        final height = contentSize.height;
        // 可见范围上下各多备一屏，滚动时下一段已在解码。
        final start = (visible.top - visible.height) / height;
        final end = (visible.bottom + visible.height) / height;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 来源画面垫在原图顶部对应的区域：正文折叠盒子抓到的是第一段
            // 分片，探索页缩略图抓到的是整张图，两者都从原图顶部开始。
            if (placeholder != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height:
                    contentSize.width * placeholder.height / placeholder.width,
                child: RawImage(image: placeholder, fit: BoxFit.fill),
              ),
            if (tiles != null)
              Positioned.fill(
                child: LongImageTilesView(
                  tiles: tiles,
                  decodeWidth: decodeWidth,
                  visibleStart: start,
                  visibleEnd: end,
                ),
              ),
          ],
        );
      },
    );
    if (hero != null) {
      viewer = HeroMode(
        enabled: !_zoomed && !_scrolled,
        child: ImageHero(tag: hero.tag, child: viewer),
      );
    }
    return viewer;
  }

  /// 来源画面是否就是原图（或第一段分片）的顶部：比例与整图或第一段相符。
  /// 第一段尚未解码时来源处可能先画出了第二段，那样的画面不能垫在顶部。
  static bool _placeholderFits(ImageViewerHero hero, LongImageTiles? tiles) {
    if (tiles == null) {
      return true;
    }
    bool close(double a, double b) => (a - b).abs() <= b * 0.02;
    final aspect = hero.aspectRatio;
    final first = tiles.tiles.first;
    return close(aspect, tiles.width / tiles.height) ||
        close(aspect, tiles.width / first.height);
  }
}
