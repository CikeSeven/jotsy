import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../controllers/explore_media_gallery_controller.dart';
import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';
import 'explore_image_viewer_page.dart';

/// 探索页“媒体画廊”全量浏览页。
///
/// 职责边界：
/// - 监听页面控制器的分页结果，滚动触底时请求续载；
/// - 负责三列网格渲染与图片查看页跳转；
/// - 不负责日记聚合统计（保持与 ExplorePageController 解耦）。
class ExploreMediaGalleryPage extends ConsumerStatefulWidget {
  const ExploreMediaGalleryPage({super.key});

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
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    if (_mediaItems.isEmpty && _isLoading) {
      return const Center(child: ExpressiveLoadingIndicator());
    }
    if (_mediaItems.isEmpty && _errorMessage != null) {
      return Center(
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
        child: Text(
          l10n.autoT0055,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: <Widget>[
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
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.biggest.shortestSide;
                      return ExploreMediaThumb(
                        source: item.source,
                        width: side,
                        height: side,
                        radius: 12,
                      );
                    },
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openViewer(index),
                    ),
                  ),
                ],
              );
            }, childCount: _mediaItems.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
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
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadMore() => _controller.loadMore();

  void _openViewer(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExploreImageViewerPage(
          mediaItems: List<ExploreMediaItem>.from(_mediaItems),
          initialIndex: initialIndex,
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
    if (isLoading) {
      return const Center(child: ExpressiveLoadingIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: TextButton(onPressed: onRetry, child: Text(l10n.autoT0056)),
      );
    }
    if (!hasMore) {
      return Center(
        child: Text(
          l10n.autoT0057,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
