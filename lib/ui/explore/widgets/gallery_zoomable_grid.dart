import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../diaries/widgets/diary_image_source.dart';
import '../../widgets/fast_scroller/fast_scroller.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../../widgets/width_layout_builder.dart';
import '../controllers/gallery_zoom_driver.dart';
import '../models/explore_view_data.dart';
import '../models/gallery_grid.dart';
import '../models/gallery_level.dart';
import '../models/gallery_scroll_index.dart';
import 'gallery_cell.dart';
import 'gallery_group_header.dart';
import 'gallery_morph_layer.dart';
import 'gallery_rows_sliver.dart';

/// 媒体画廊的网格本体：按档位分组排布、右缘快速滚动条、捏合换档。
///
/// 输入：按发表时间排好的全部媒体 [items]（随分批加载变长）与筛选代号
/// [generation]、正式网格的 [scrollController]、页脚 [footer]（高
/// [footerExtent]）与空态 [empty]；输出：点按 / 长按某张图的回调（整体下标）。
///
/// - 档位只在本组件里（[GalleryZoom]，默认 4 列按天）。每档的分组与行布局
///   （[GalleryGrid]）按“条数 + 代号 + 宽度”缓存，一个 sliver 排完全部行。
/// - 捏合（小米相册式）由 [GalleryZoomDriver] 驱动：页面不动，只有图片
///   跟着手指从当前档的位置与大小走到目标档；途中正式网格隐藏且不重建，
///   过渡画在 [GalleryMorphLayer] 一块画布上，手势结束时正式网格按最终档位
///   重建一次。捏合期间滚动物理吞掉拖动与惯性，快速滚动条停用。
/// - 快速滚动条按行换算（[GalleryScrollIndex]），行位置预先已知，跳转一步
///   到位（`maxSeekItemsPerFrame` 不限）。
class GalleryZoomableGrid extends StatefulWidget {
  const GalleryZoomableGrid({
    super.key,
    required this.items,
    required this.generation,
    required this.scrollController,
    required this.footer,
    required this.onOpen,
    required this.onLongPress,
    required this.heroTagOf,
    this.empty,
  });

  /// 页脚（加载中 / 重试 / 已到底）的高度，不含底部安全区。
  static const double footerExtent = 72;

  static const double _gap = 2;
  static const double _padding = AppSpacing.xs;
  static const double _headerInset = AppSpacing.m;

  final List<ExploreMediaItem> items;
  final int generation;
  final ScrollController scrollController;
  final Widget footer;
  final Widget? empty;
  final GalleryCellTap onOpen;
  final ValueChanged<int> onLongPress;
  final Object Function(String source) heroTagOf;

  @override
  State<GalleryZoomableGrid> createState() => _GalleryZoomableGridState();
}

class _GalleryZoomableGridState extends State<GalleryZoomableGrid>
    with SingleTickerProviderStateMixin {
  final GlobalKey _listKey = GlobalKey();
  final GalleryLiveImages _liveImages = GalleryLiveImages();
  late final GalleryZoomDriver _driver = GalleryZoomDriver(
    vsync: this,
    zoomOf: () => _zoom,
    gridFor: _gridFor,
    positionOf: () => widget.scrollController.hasClients
        ? widget.scrollController.position
        : null,
    trailingExtentOf: () => _trailingExtent,
    settleDuration: () =>
        ExpressiveMotion.duration(context, ExpressiveMotion.medium),
    sourceOf: (int index) => widget.items[index].source,
    providerFor: (String source, GalleryZoom zoom) =>
        _providerFor(source, _decodeExtentFor(zoom)),
    liveImageOf: (String source) => _liveImages[source],
    imageConfigurationOf: () => createLocalImageConfiguration(context),
    onCommit: (GalleryZoom zoom) => setState(() => _zoom = zoom),
  );
  late final _GalleryScrollPhysics _physics = _GalleryScrollPhysics(
    frozen: _driver.frozen,
  );

  GalleryZoom _zoom = GalleryZoom.initial;
  double _width = 0;
  double _trailingExtent = GalleryZoomableGrid.footerExtent;

  /// 缓存：媒体条数、筛选代号与宽度都没变时沿用各层级的分组与各档的布局。
  (int, int, double)? _cacheKey;
  final Map<GalleryLevel, GalleryGroups> _groups =
      <GalleryLevel, GalleryGroups>{};
  final Map<GalleryZoom, GalleryGrid> _grids = <GalleryZoom, GalleryGrid>{};
  GalleryScrollIndex? _scrollIndex;

  @override
  void didUpdateWidget(GalleryZoomableGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) _driver.reset();
  }

  @override
  void dispose() {
    _driver.dispose();
    super.dispose();
  }

  void _syncCaches(double width) {
    final key = (widget.items.length, widget.generation, width);
    if (key == _cacheKey) return;
    _cacheKey = key;
    _width = width;
    _groups.clear();
    _grids.clear();
    _scrollIndex = null;
  }

  GalleryGroups _groupsFor(GalleryLevel level) =>
      _groups[level] ??= GalleryGroups.of(widget.items, level);

  GalleryGrid _gridFor(GalleryZoom zoom) => _grids[zoom] ??= GalleryGrid(
    groups: _groupsFor(zoom.level).groups,
    columns: zoom.columnsFor(_width),
    width: _width,
    padding: GalleryZoomableGrid._padding,
    gap: GalleryZoomableGrid._gap,
    headerExtent: GalleryGroupHeader.extentFor(zoom.level),
  );

  GalleryScrollIndex _indexFor(GalleryGrid grid, String locale) {
    final cached = _scrollIndex;
    if (cached != null && identical(cached.grid, grid)) return cached;
    return _scrollIndex = GalleryScrollIndex(
      grid: grid,
      level: _zoom.level,
      locale: locale,
    );
  }

  /// 缩略图的解码边长（物理像素）：按 [GalleryZoom.decodeReference] 那一档
  /// 的格子大小，同一族的档位共用一份解码。
  int _decodeExtentFor(GalleryZoom zoom) {
    final reference = zoom.decodeReference;
    final extent = GalleryGrid.cellExtentFor(
      width: _width,
      columns: reference.columnsFor(_width),
      padding: GalleryZoomableGrid._padding,
      gap: GalleryZoomableGrid._gap,
    );
    return (extent * MediaQuery.devicePixelRatioOf(context)).ceil();
  }

  /// 与格子同一个 provider（同一缓存键），过渡里加载的图换档后直接命中。
  static ImageProvider _providerFor(String source, int extent) =>
      boundedImageProvider(
        diaryImageProvider(source),
        width: extent,
        height: extent,
        cover: true,
      );

  void _handleTap(int index, BuildContext cellContext) {
    if (_driver.suppressTaps) return;
    widget.onOpen(index, cellContext);
  }

  void _handleLongPress(int index) {
    if (_driver.suppressTaps) return;
    widget.onLongPress(index);
  }

  /// 桌面：按住 Ctrl 滚动滚轮换档（向上放大、向下缩小），这次滚动不再
  /// 滚动列表。
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !HardwareKeyboard.instance.isControlPressed ||
        event.scrollDelta.dy == 0 ||
        widget.items.isEmpty) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _driver.step(
        zoomIn: event.scrollDelta.dy < 0,
        focal: event.localPosition,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    _trailingExtent = GalleryZoomableGrid.footerExtent + bottomInset;
    final locale = context.l10n.localeName;
    return WidthLayoutBuilder(
      builder: (BuildContext context, double width) {
        _syncCaches(width);
        final grid = _gridFor(_zoom);
        final index = _indexFor(grid, locale);
        final pinchable = widget.items.isNotEmpty;
        // 正式网格只在数据、宽度或档位变化时重建；过渡开始 / 结束只切换
        // 下面 ValueListenableBuilder 里的显隐，不牵动这棵子树。
        final scrollView = CustomScrollView(
          controller: widget.scrollController,
          physics: _physics,
          scrollBehavior: ScrollConfiguration.of(
            context,
          ).copyWith(scrollbars: false),
          slivers: <Widget>[
            _rowsSliver(grid, _zoom),
            if (widget.items.isEmpty && widget.empty != null)
              SliverFillRemaining(hasScrollBody: false, child: widget.empty),
            SliverToBoxAdapter(
              child: SizedBox(
                height: _trailingExtent,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: widget.footer,
                ),
              ),
            ),
          ],
        );
        return Listener(
          onPointerDown: pinchable
              ? (event) =>
                    _driver.pointerDown(event.pointer, event.localPosition)
              : null,
          onPointerMove: (event) =>
              _driver.pointerMove(event.pointer, event.localPosition),
          onPointerUp: (event) => _driver.pointerUp(event.pointer),
          onPointerCancel: (event) => _driver.pointerUp(event.pointer),
          onPointerPanZoomStart: pinchable
              ? (event) => _driver.panZoomStart(event.localPosition)
              : null,
          onPointerPanZoomUpdate: (event) => _driver.panZoomUpdate(event.scale),
          onPointerPanZoomEnd: (_) => _driver.panZoomEnd(),
          onPointerSignal: _handlePointerSignal,
          child: ClipRect(
            child: ValueListenableBuilder<GalleryMorph?>(
              valueListenable: _driver.morph,
              child: scrollView,
              builder:
                  (BuildContext context, GalleryMorph? morph, Widget? view) {
                    return Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        FastScroller(
                          listKey: _listKey,
                          itemCount: grid.rowCount,
                          loadedCount: grid.rowCount,
                          labelBuilder: index.labelAt,
                          sections: index.sections,
                          listIdentity: (widget.generation, _zoom),
                          padding: EdgeInsets.only(bottom: bottomInset),
                          enabled: morph == null,
                          maxSeekItemsPerFrame: double.infinity,
                          // 过渡期间不画正式网格（不透明度 0 不绘制子树），它的
                          // 格子保持挂载，过渡直接取用它们的画面。
                          child: Opacity(
                            opacity: morph == null ? 1 : 0,
                            child: view,
                          ),
                        ),
                        if (morph != null)
                          IgnorePointer(
                            child: ExcludeSemantics(
                              child: GalleryMorphLayer(
                                driver: _driver,
                                morph: morph,
                                headerInset: GalleryZoomableGrid._headerInset,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
            ),
          ),
        );
      },
    );
  }

  /// 正式网格的全部行，挂 [_listKey] 供快速滚动条读布局。
  Widget _rowsSliver(GalleryGrid grid, GalleryZoom zoom) {
    final items = _groupsFor(zoom.level).ordered;
    final decodeExtent = _decodeExtentFor(zoom);
    // 另一族档位的解码边长：换档后自己的尺寸还没解码好时先用它。
    final fallbackExtent = _decodeExtentFor(
      zoom.decodeReference == GalleryZoom.day
          ? GalleryZoom.month
          : GalleryZoom.day,
    );
    return GalleryRowsSliver(
      key: _listKey,
      grid: grid,
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int row) {
          if (grid.isHeader(row)) {
            final group = grid.groupOfRow(row);
            return GalleryGroupHeader(
              date: group.key,
              level: zoom.level,
              count: group.items.length,
              inset: GalleryZoomableGrid._headerInset,
            );
          }
          return GalleryCellRow(
            items: items,
            first: grid.firstItemOfRow(row),
            count: grid.itemCountOfRow(row),
            extent: grid.cellExtent,
            gap: GalleryZoomableGrid._gap,
            padding: GalleryZoomableGrid._padding,
            radius: zoom.cornerRadius,
            decodeExtent: decodeExtent,
            fallbackExtent: fallbackExtent,
            interactive: true,
            liveImages: _liveImages,
            heroTagOf: widget.heroTagOf,
            onTap: _handleTap,
            onLongPress: _handleLongPress,
          );
        },
        childCount: grid.rowCount,
        addAutomaticKeepAlives: false,
      ),
    );
  }
}

/// 正式网格的滚动物理：捏合与收尾期间（[frozen]）吞掉拖动位移与松手
/// 惯性，两根手指上下移动时列表不跟着走；其余照常。
class _GalleryScrollPhysics extends ScrollPhysics {
  const _GalleryScrollPhysics({required this.frozen, super.parent});

  final ValueListenable<bool> frozen;

  @override
  _GalleryScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _GalleryScrollPhysics(frozen: frozen, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      frozen.value ? 0 : super.applyPhysicsToUserOffset(position, offset);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (frozen.value && !position.outOfRange) return null;
    return super.createBallisticSimulation(position, velocity);
  }
}
