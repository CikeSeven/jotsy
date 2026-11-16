import 'dart:async';

import 'package:flutter/material.dart';
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
import '../controllers/explore_media_gallery_controller.dart';
import '../models/explore_media_gallery_filter.dart';
import '../models/explore_view_data.dart';
import '../widgets/gallery_filter_menu.dart';
import '../widgets/gallery_time_range_picker.dart';
import '../widgets/gallery_zoomable_grid.dart';

/// 探索页“媒体画廊”全量浏览页。
///
/// 职责边界（页面只做装配）：
/// - 订阅 [ExploreMediaGalleryController]：打开后在后台分批建好全部图片的
///   索引（来源 + 日期，不解码图片），首批到了即显示，之后的批次接在末尾；
/// - 网格、按档位分组、捏合换档与快速滚动条在 [GalleryZoomableGrid]；
/// - 顶栏 ⋮ 菜单：日记本图片（不列上锁的本子；日记本功能关闭时不出现）、
///   时间选择（内联日历，见 [GalleryTimeRangePicker]）与排序，换了就经
///   [ExploreMediaGalleryController.configure] 从头重查并回到顶部；
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
    extends ConsumerState<ExploreMediaGalleryPage> {
  final ScrollController _scrollController = ScrollController();
  late final ExploreMediaGalleryController _controller;
  final GalleryTimePickerBackHandle _timePickerBack =
      GalleryTimePickerBackHandle();

  GalleryNotebookChoice _notebookChoice = GalleryNotebookChoice.all;

  /// 首批结果到达（或确认没有结果）前用整页的加载 / 出错；之后换筛选也
  /// 一直留在网格里（空态与加载画在网格内），AnimatedSwitcher 不会同时
  /// 挂着新旧两个用同一个 [_scrollController] 的滚动视图。
  bool _loadedOnce = false;

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
    _scrollController.dispose();
    super.dispose();
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
    return GalleryZoomableGrid(
      key: const ValueKey<String>('grid'),
      items: _mediaItems,
      generation: _controller.generation,
      scrollController: _scrollController,
      empty: _mediaItems.isEmpty && !_isLoading && _errorMessage == null
          ? const _EmptyHint()
          : null,
      footer: _GalleryFooter(
        isLoading: _isLoading,
        // 空结果时由空态说明，不再写“已到底”。
        hasMore: _hasMore || _mediaItems.isEmpty,
        errorMessage: _errorMessage,
        onRetry: _loadMore,
      ),
      heroTagOf: _heroTag,
      onOpen: _openViewer,
      onLongPress: (int index) =>
          unawaited(_openDiary(_mediaItems[index].diaryId)),
    );
  }

  void _handleGalleryChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      // 分批加载：第一批到了就进网格，后面的批次接在网格末尾。
      if (_controller.items.isNotEmpty ||
          (!_controller.isLoading && !_controller.hasMore)) {
        _loadedOnce = true;
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
