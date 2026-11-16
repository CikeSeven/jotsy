import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_open_flow.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../notebooks/models/notebook_scope_resolver.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_tree.dart';
import '../../notebooks/viewmodels/notebook_tree_rows.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/width_layout_builder.dart';
import '../controllers/explore_media_gallery_controller.dart';
import '../models/explore_media_gallery_filter.dart';
import '../models/explore_view_data.dart';
import '../models/gallery_layout.dart';
import '../models/gallery_level.dart';
import '../widgets/explore_shared_widgets.dart';
import '../widgets/gallery_filter_menu.dart';
import '../widgets/gallery_group_header.dart';
import '../widgets/gallery_time_range_picker.dart';

/// 探索页“媒体画廊”全量浏览页。
///
/// 职责边界：
/// - 监听页面控制器的分页结果，滚动触底时请求续载；
/// - 按发表日期分组（[GalleryZoom] 四档：3 / 4 列按天、8 列按月、10 列按年，
///   宽窗口按宽度加列），每组标题吸顶、被下一组顶走；双指捏合换档（桌面
///   为 Ctrl + 滚轮或触控板捏合），换档前后视口顶部停在同一张图附近；
/// - 顶栏 ⋮ 菜单：日记本图片（不列上锁的本子；日记本功能关闭时不出现）、
///   时间选择（内联日历，见 [GalleryTimeRangePicker]）与排序，换了就经
///   [ExploreMediaGalleryController.configure] 从头重查；
/// - 点按缩略图打开看图页（看图页长按“打开日记”），长按缩略图直接打开
///   所在日记；
/// - 不负责日记聚合统计（保持与 ExplorePageController 解耦）。
class ExploreMediaGalleryPage extends ConsumerStatefulWidget {
  const ExploreMediaGalleryPage({super.key});

  @override
  ConsumerState<ExploreMediaGalleryPage> createState() =>
      _ExploreMediaGalleryPageState();
}

class _ExploreMediaGalleryPageState
    extends ConsumerState<ExploreMediaGalleryPage>
    with SingleTickerProviderStateMixin {
  static const double _prefetchExtent = 720;
  static const double _cellGap = 2;

  final ScrollController _scrollController = ScrollController();
  late final ExploreMediaGalleryController _controller;
  final GalleryTimePickerBackHandle _timePickerBack =
      GalleryTimePickerBackHandle();

  GalleryZoom _zoom = GalleryZoom.closeUp;
  GalleryNotebookChoice _notebookChoice = GalleryNotebookChoice.all;

  /// 首次加载完成前用整页的加载 / 空态 / 出错；之后换筛选也一直留在网格里
  /// （空态与加载画在网格内），AnimatedSwitcher 不会同时挂着新旧两个用同一
  /// 个 [_scrollController] 的滚动视图。
  bool _loadedOnce = false;

  /// 分组缓存：媒体列表、筛选代号与分组层级都没变时沿用。
  GalleryGroups _groups = GalleryGroups.empty;
  (int, int, GalleryLevel)? _groupsKey;

  /// 最近一次布局时网格的列数与宽度（已扣内边距），换档时据此找回锚点。
  int _columns = GalleryZoom.closeUp.columns;
  double _gridWidth = 0;

  /// 换档时整个网格从 0.95 弹回 1，提示格子大小变了（不重建滚动视图）。
  late final AnimationController _zoomPulse = AnimationController(
    vsync: this,
    value: 1,
  );
  late final Animation<double> _zoomScale = Tween<double>(begin: 0.95, end: 1)
      .animate(
        CurvedAnimation(parent: _zoomPulse, curve: ExpressiveMotion.spatial),
      );

  /// 双指捏合：直接跟踪两根手指的距离，不走手势竞技场（缩放手势会被列表
  /// 的竖向拖动抢走）。每跨过一档就把基准换成当前距离，一次捏合可连跨几档。
  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _pinchBase;

  /// 触控板捏合（桌面）的基准比例，规则同上。
  double _panZoomBase = 1;

  List<ExploreMediaItem> get _mediaItems => _controller.items;
  bool get _isLoading => _controller.isLoading;
  bool get _hasMore => _controller.hasMore;
  String? get _errorMessage =>
      _controller.hasError ? context.l10n.autoT0197 : null;

  @override
  void initState() {
    super.initState();
    _controller = ExploreMediaGalleryController(
      database: ref.read(appDatabaseProvider),
    )..addListener(_handleGalleryChanged);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleGalleryChanged)
      ..dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _zoomPulse.dispose();
    super.dispose();
  }

  GalleryGroups _currentGroups() {
    final key = (_mediaItems.length, _controller.generation, _zoom.level);
    if (_groupsKey != key) {
      _groups = GalleryGroups.of(_mediaItems, _zoom.level);
      _groupsKey = key;
    }
    return _groups;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppPageBackground(
      area: AppBackgroundArea.other,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            centerTitle: true,
            title: Text(l10n.autoT0054),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).pop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
            actions: <Widget>[
              ExpressiveMenuButton(
                tooltip: l10n.exploreGalleryMenuTooltip,
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
                items: _buildMenuItems(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          // 首次加载 → 网格 / 空态 / 错误之间交叉淡入，而不是硬切；网格内追加
          // 分页、换筛选时 key 不变，不会重复淡入。
          body: AnimatedSwitcher(
            duration: ExpressiveMotion.duration(
              context,
              ExpressiveMotion.medium,
            ),
            switchInCurve: ExpressiveMotion.effects,
            switchOutCurve: ExpressiveMotion.exit,
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  // ---- 顶栏菜单 ----

  List<Widget> _buildMenuItems(BuildContext context) {
    final l10n = context.l10n;
    final filter = _controller.filter;
    final notebooksEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.notebooks),
    );
    final tree = ref.watch(notebookTreeProvider);
    return <Widget>[
      if (notebooksEnabled)
        ExpressiveSubmenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.book),
          menuChildren: <Widget>[
            GalleryNotebookFilterMenu(
              // 上锁的本子要先验证才能进，这里不列（隐藏的本子从书架可直接
              // 进入，照常列出）。
              rows: tree == null
                  ? const <NotebookTreeRow>[]
                  : notebookTreeRows(
                      tree,
                      include: (NotebookView notebook) =>
                          notebook.effectiveVisibility !=
                          NotebookVisibility.locked,
                    ),
              selected: _notebookChoice,
              onSelected: _applyNotebook,
            ),
          ],
          child: Text(l10n.exploreGalleryNotebookFilter),
        ),
      ExpressiveSubmenuItem(
        leadingIcon: const FaIcon(FontAwesomeIcons.calendarDays),
        onCollapseRequest: _timePickerBack.handle,
        menuChildren: <Widget>[
          GalleryTimeRangePicker(
            initialRange: filter.range,
            backHandle: _timePickerBack,
            // 回调触发时再取当前筛选：同一次打开菜单里可能先改了排序。
            onApply: (DateTimeRange range) =>
                _configure(_controller.filter.copyWith(range: () => range)),
            onClear: () =>
                _configure(_controller.filter.copyWith(range: () => null)),
          ),
        ],
        child: Text(l10n.exploreGalleryTimeRange),
      ),
      ExpressiveSubmenuItem(
        leadingIcon: const FaIcon(FontAwesomeIcons.arrowDownWideShort),
        menuChildren: <Widget>[
          GallerySortMenu(
            newestFirst: filter.newestFirst,
            onChanged: (bool newestFirst) => _configure(
              _controller.filter.copyWith(newestFirst: newestFirst),
            ),
          ),
        ],
        child: Text(l10n.exploreGallerySort),
      ),
    ];
  }

  void _configure(ExploreMediaGalleryFilter filter) {
    if (filter == _controller.filter) return;
    _controller.configure(filter);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _applyNotebook(GalleryNotebookChoice choice) {
    _notebookChoice = choice;
    final scope = _scopeFor(
      choice,
      ref.read(notebooksProvider).value ?? const <NotebookView>[],
      ref.read(notebookTreeProvider),
    );
    _configure(_controller.filter.copyWith(scope: scope));
  }

  /// 选中项对应的查询范围；那本已被删除时退回全部日记。
  static DiaryListScope _scopeFor(
    GalleryNotebookChoice choice,
    List<NotebookView> notebooks,
    NotebookTree? tree,
  ) {
    if (choice == GalleryNotebookChoice.unfiled) return DiaryListScope.unfiled;
    if (choice is! GalleryNotebookOf) return DiaryListScope.all;
    for (final notebook in notebooks) {
      if (notebook.id == choice.notebookId) {
        return resolveNotebookScope(notebook, tree: tree);
      }
    }
    return DiaryListScope.all;
  }

  // ---- 换档（捏合 / Ctrl + 滚轮）----

  void _changeZoom(GalleryZoom? next) {
    if (next == null || next == _zoom) return;
    HapticFeedback.selectionClick();
    final anchor = _scrollController.hasClients && _gridWidth > 0
        ? _layout(_currentGroups(), _columns).anchorAt(_scrollController.offset)
        : null;
    setState(() => _zoom = next);
    _zoomPulse
      ..duration = ExpressiveMotion.duration(context, ExpressiveMotion.standard)
      ..forward(from: 0);
    if (anchor == null) return;
    // 新档位布局后，把换档前视口顶部那张图所在的行重新放到顶部。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _layout(_currentGroups(), _columns).offsetOf(anchor);
      if (target == null) return;
      final position = _scrollController.position;
      _scrollController.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  GalleryLayout _layout(GalleryGroups groups, int columns) => GalleryLayout(
    groups: groups.groups,
    columns: columns,
    gridWidth: _gridWidth,
    headerExtent: GalleryGroupHeader.extent,
    gap: _cellGap,
  );

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) _pinchBase = _pinchDistance();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final base = _pinchBase;
    final distance = _pinchDistance();
    if (base == null || distance == null || base <= 0) return;
    if (_stepZoom(distance / base)) _pinchBase = distance;
  }

  void _onPointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length != 2) _pinchBase = null;
  }

  double? _pinchDistance() {
    if (_pointers.length != 2) return null;
    final points = _pointers.values.toList(growable: false);
    return (points[1] - points[0]).distance;
  }

  /// 比例越过阈值就换一档：捏小（< 0.9）缩小格子，张开（> 1.11）放大。
  bool _stepZoom(double ratio) {
    final next = ratio < 0.9
        ? _zoom.zoomedOut
        : ratio > 1.11
        ? _zoom.zoomedIn
        : null;
    if (next == null) return false;
    _changeZoom(next);
    return true;
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) => _panZoomBase = 1;

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (_stepZoom(event.scale / _panZoomBase)) _panZoomBase = event.scale;
  }

  /// 桌面：按住 Ctrl 滚动滚轮换档（向上放大、向下缩小），这次滚动不再
  /// 滚动列表。
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !HardwareKeyboard.instance.isControlPressed ||
        event.scrollDelta.dy == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _changeZoom(event.scrollDelta.dy < 0 ? _zoom.zoomedIn : _zoom.zoomedOut);
    });
  }

  // ---- 内容 ----

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    if (!_loadedOnce) {
      // 首次加载在首帧之后才发起，此前 isLoading 仍为 false：把“还没加载
      // 过”也当作加载中，避免先闪一帧“暂无媒体”。本地查询通常很快，指示器
      // 延迟出现。
      final neverLoaded = _hasMore && _errorMessage == null;
      if (_mediaItems.isEmpty && (_isLoading || neverLoaded)) {
        return const DelayedLoadingIndicator(key: ValueKey<String>('loading'));
      }
      if (_mediaItems.isEmpty && _errorMessage != null) {
        return Center(
          key: const ValueKey<String>('error'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  // 空状态与出错提示直接画在页面背景上，有背景图时加可读性兜底。
                  style: AppPageBackdrop.onBackgroundTextStyle(
                    context,
                    Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  style: AppGlassField.tonalButtonStyle(context),
                  onPressed: _loadMore,
                  child: Text(l10n.autoT0056),
                ),
              ],
            ),
          ),
        );
      }
    }
    final groups = _currentGroups();
    return Listener(
      key: const ValueKey<String>('grid'),
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      onPointerPanZoomStart: _onPanZoomStart,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      onPointerSignal: _onPointerSignal,
      child: ScaleTransition(
        scale: _zoomScale,
        // 列数随网格实际宽度增加（见 [GalleryZoom.columnsFor]），缩略图大小
        // 保持在手机上的体感，不会在宽窗口里被放大成几张大图。
        child: WidthLayoutBuilder(
          builder: (BuildContext context, double width) {
            _columns = _zoom.columnsFor(width);
            _gridWidth = width - AppSpacing.m * 2;
            return _buildScrollView(groups, _columns);
          },
        ),
      ),
    );
  }

  Widget _buildScrollView(GalleryGroups groups, int columns) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: <Widget>[
        for (final group in groups.groups) _buildGroup(group, columns),
        if (_mediaItems.isEmpty && !_isLoading && _errorMessage == null)
          const SliverFillRemaining(hasScrollBody: false, child: _EmptyHint()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              12,
              AppSpacing.m,
              AppSpacing.xl,
            ),
            child: _GalleryFooter(
              isLoading: _isLoading,
              // 空结果时由上面的空态说明，不再写“已到底”。
              hasMore: _hasMore || _mediaItems.isEmpty,
              errorMessage: _errorMessage,
              onRetry: _loadMore,
            ),
          ),
        ),
      ],
    );
  }

  /// 一组：吸顶的日期标题 + 网格。组走完时标题被下一组的标题顶走。
  Widget _buildGroup(GalleryGroup group, int columns) {
    return SliverMainAxisGroup(
      key: ValueKey<DateTime>(group.key),
      slivers: <Widget>[
        PinnedHeaderSliver(
          child: GalleryGroupHeader(
            title: GalleryGroupHeader.titleFor(context, group.key, _zoom.level),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = group.items[index];
              return _GalleryCell(
                item: item,
                heroTag: _heroTag(item.source),
                onTap: (BuildContext cellContext) =>
                    _openViewer(group.start + index, cellContext),
                onLongPress: () => unawaited(_openDiary(item.diaryId)),
              );
            }, childCount: group.items.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _cellGap,
              crossAxisSpacing: _cellGap,
              childAspectRatio: 1,
            ),
          ),
        ),
      ],
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoading || !_hasMore) {
      return;
    }
    if (_scrollController.position.extentAfter < _prefetchExtent) {
      _loadMore();
    }
  }

  void _handleGalleryChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      if (!_controller.isLoading &&
          (_controller.items.isNotEmpty || !_controller.hasMore)) {
        _loadedOnce = true;
      }
    });
    // 宽窗口一行放得多，一页结果可能填不满屏幕：没有可滚动的距离就不会
    // 触发滚动预取，这里在布局后补查一次，填满为止（或没有更多）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <= 0) {
        _handleScroll();
      }
    });
  }

  Future<void> _loadMore() => _controller.loadMore();

  static Object _heroTag(String source) =>
      ImageViewerHeroTag('explore_gallery', source);

  /// 打开看图页：缩略图以共享元素展开成原图，返回时飞回原格子。分组沿用
  /// 列表顺序，网格里第几张就是列表里第几张。每张图带上所在日记，长按
  /// 面板可直接打开它。
  void _openViewer(int initialIndex, BuildContext cellContext) {
    final source = _mediaItems[initialIndex].source;
    openImageViewer(
      context,
      items: _mediaItems
          .map(
            (item) =>
                ImageViewerItem(source: item.source, diaryId: item.diaryId),
          )
          .toList(growable: false),
      initialIndex: initialIndex,
      hero: ImageViewerHero.capture(cellContext, tag: _heroTag(source)),
      onOpenDiary: (String diaryId) => unawaited(_openDiary(diaryId)),
    );
  }

  /// 打开所在日记（看图页长按“打开日记”、长按缩略图）：预览页（“打开日记
  /// 时直接编辑”开启时为编辑页，见 [openDiaryPage]）压在当前页之上（单篇
  /// 入口，不左右翻），返回时回到原处。在里面删除日记时给 4 秒撤销，撤销即
  /// 从回收站恢复。
  Future<void> _openDiary(String diaryId) async {
    final database = ref.read(appDatabaseProvider);
    final result = await openDiaryPage(context, ref, diaryId: diaryId);
    final deletedId = result?.diaryId;
    if (deletedId == null || !mounted) {
      return;
    }
    final l10n = context.l10n;
    final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(l10n.autoT0075),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(label: l10n.commonUndo, onPressed: () {}),
      ),
    );
    if (reason == SnackBarClosedReason.action) {
      await database.restoreDiary(deletedId, touchUpdatedAt: false);
    }
  }
}

/// 网格里的一格：缩略图（看图页的共享元素来源）+ 叠在上面的水波纹层。
class _GalleryCell extends StatelessWidget {
  const _GalleryCell({
    required this.item,
    required this.heroTag,
    required this.onTap,
    required this.onLongPress,
  });

  static const double _radius = 4;

  final ExploreMediaItem item;
  final Object heroTag;
  final ValueChanged<BuildContext> onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    // 缩略图本身不透明，水波纹需画在叠于其上的透明 Material 上。点按时从
    // 格子自己的 context 抓取已绘制的缩略图作为看图页的飞入画面。
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ImageViewerHeroSource(
          tag: heroTag,
          borderRadius: BorderRadius.circular(_radius),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide;
              return ExploreMediaThumb(
                source: item.source,
                width: side,
                height: side,
                radius: _radius,
              );
            },
          ),
        ),
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(_radius),
            onTap: () => onTap(context),
            onLongPress: onLongPress,
          ),
        ),
      ],
    );
  }
}

/// “暂无媒体”：画在页面背景上，有背景图时加可读性兜底。
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Text(
          context.l10n.autoT0055,
          textAlign: TextAlign.center,
          style: AppPageBackdrop.onBackgroundTextStyle(
            context,
            Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryFooter extends StatelessWidget {
  const _GalleryFooter({
    required this.isLoading,
    required this.hasMore,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final Widget content;
    if (isLoading) {
      content = const DelayedLoadingIndicator(
        key: ValueKey<String>('footer_loading'),
      );
    } else if (errorMessage != null) {
      content = Center(
        key: const ValueKey<String>('footer_error'),
        child: TextButton(onPressed: onRetry, child: Text(l10n.autoT0056)),
      );
    } else if (!hasMore) {
      content = Center(
        key: const ValueKey<String>('footer_end'),
        // “已到底”画在网格下方的页面背景上。
        child: Text(
          l10n.autoT0057,
          style: AppPageBackdrop.onBackgroundTextStyle(
            context,
            Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      content = const SizedBox.shrink(key: ValueKey<String>('footer_idle'));
    }
    // 指示器、重试与“已到底”之间淡入淡出，而不是硬切。
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      child: content,
    );
  }
}
