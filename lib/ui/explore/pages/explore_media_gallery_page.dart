import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_service.dart';
import '../controllers/explore_media_gallery_controller.dart';
import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';

/// 探索页“媒体画廊”全量浏览页。
///
/// 职责边界：
/// - 监听页面控制器的分页结果，滚动触底时请求续载；
/// - 负责三列网格渲染与图片查看页跳转；看图页长按“打开日记”打开图片所在
///   的日记（叠在看图页之上，返回时回到刚才那张图）；
/// - 不负责日记聚合统计（保持与 ExplorePageController 解耦）。
class ExploreMediaGalleryPage extends ConsumerStatefulWidget {
  const ExploreMediaGalleryPage({super.key});

  /// 网格列数：页面宽 [width] 每 160 一列，至少 3 列（手机上恒为 3 列）。
  static int galleryColumns(double width) => math.max(3, width ~/ 160);

  @override
  ConsumerState<ExploreMediaGalleryPage> createState() =>
      _ExploreMediaGalleryPageState();
}

class _ExploreMediaGalleryPageState
    extends ConsumerState<ExploreMediaGalleryPage> {
  static const double _prefetchExtent = 720;

  final ScrollController _scrollController = ScrollController();
  late final ExploreMediaGalleryController _controller;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppTopBar(
        centerTitle: true,
        title: Text(l10n.autoT0054),
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      // 首次加载 → 网格 / 空态 / 错误之间交叉淡入，而不是硬切；网格内追加
      // 分页时 key 不变，不会重复淡入。
      body: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    // 首次加载在首帧之后才发起，此前 isLoading 仍为 false：把“还没加载过”也
    // 当作加载中，避免先闪一帧“暂无媒体”。本地查询通常很快，指示器延迟出现。
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _loadMore,
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (_mediaItems.isEmpty) {
      return Center(
        key: const ValueKey<String>('empty'),
        child: Text(
          l10n.autoT0055,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return CustomScrollView(
      key: const ValueKey<String>('grid'),
      controller: _scrollController,
      slivers: <Widget>[
        // 列数随页面宽度增加（见 [ExploreMediaGalleryPage.galleryColumns]），缩略图大小保持在手机上
        // 的体感，不会在宽窗口里被放大成几张大图。
        SliverLayoutBuilder(
          builder: (BuildContext context, SliverConstraints constraints) =>
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  AppSpacing.m,
                  AppSpacing.m,
                  0,
                ),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = _mediaItems[index];
                    // 缩略图本身不透明，水波纹需画在叠于其上的透明 Material 上。
                    // Builder 提供格子自己的 context：点按时从这里抓取已绘制的缩略图
                    // 作为看图页的飞入画面（delegate 的 context 是整个网格）。
                    return Builder(
                      builder: (cellContext) => Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          ImageViewerHeroSource(
                            tag: _heroTag(item.source),
                            borderRadius: BorderRadius.circular(_thumbRadius),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final side = constraints.biggest.shortestSide;
                                return ExploreMediaThumb(
                                  source: item.source,
                                  width: side,
                                  height: side,
                                  radius: _thumbRadius,
                                );
                              },
                            ),
                          ),
                          Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(_thumbRadius),
                              onTap: () => _openViewer(index, cellContext),
                            ),
                          ),
                        ],
                      ),
                    );
                  }, childCount: _mediaItems.length),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: ExploreMediaGalleryPage.galleryColumns(
                      constraints.crossAxisExtent,
                    ),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                ),
              ),
        ),
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
              hasMore: _hasMore,
              errorMessage: _errorMessage,
              onRetry: _loadMore,
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
    setState(() {});
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

  static const double _thumbRadius = 12;

  static Object _heroTag(String source) =>
      ImageViewerHeroTag('explore_gallery', source);

  /// 打开看图页：缩略图以共享元素展开成原图，返回时飞回原格子。每张图带上
  /// 所在日记，长按面板可直接打开它。
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

  /// 看图页长按“打开日记”：预览页压在看图页之上（单篇入口，不左右翻），
  /// 返回时回到刚才那张图。在预览页删除日记时给 4 秒撤销，撤销即从回收站
  /// 恢复；提示落在返回后的看图页上。
  Future<void> _openDiary(String diaryId) async {
    final database = ref.read(appDatabaseProvider);
    final result = await Navigator.of(context).push<DiaryPreviewResult?>(
      MaterialPageRoute<DiaryPreviewResult?>(
        builder: (BuildContext context) => DiaryPreviewPage(diaryId: diaryId),
      ),
    );
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
        child: Text(
          l10n.autoT0057,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
