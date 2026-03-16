import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../controllers/explore_content_extractor.dart';
import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';
import 'explore_image_viewer_page.dart';

/// 探索页“媒体画廊”全量浏览页。
///
/// 职责边界：
/// - 负责分页拉取、按 source 去重、滚动触底续载；
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
  static const int _candidateBatchSize = 40;
  static const int _targetMediaAppendCount = 30;
  static const int _maxBatchRoundsPerLoad = 8;
  static const double _prefetchExtent = 720;

  final ScrollController _scrollController = ScrollController();
  final ExploreContentExtractor _extractor = const ExploreContentExtractor();
  final List<ExploreMediaItem> _mediaItems = <ExploreMediaItem>[];
  final Set<String> _seenSources = <String>{};

  int _nextOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMore();
    });
  }

  @override
  void dispose() {
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
      return const Center(child: CircularProgressIndicator());
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
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openViewer(index),
                child: ExploreMediaThumb(
                  source: item.source,
                  width: double.infinity,
                  height: double.infinity,
                  radius: 12,
                ),
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

  /// 分批加载策略：
  /// - 每轮先按 offset 取一批候选日记；
  /// - 从候选里提取图片来源并按 source 去重；
  /// - 如果本轮新增图片不够，再继续取下一批，直到达到目标数量或无更多数据。
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = ref.read(appDatabaseProvider);
      final localSources = Set<String>.from(_seenSources);
      final appended = <ExploreMediaItem>[];
      var localOffset = _nextOffset;
      var localHasMore = _hasMore;
      var rounds = 0;

      while (appended.length < _targetMediaAppendCount &&
          localHasMore &&
          rounds < _maxBatchRoundsPerLoad) {
        rounds += 1;
        final diaries = await db.getActiveDiariesPage(
          limit: _candidateBatchSize,
          offset: localOffset,
        );
        if (diaries.isEmpty) {
          localHasMore = false;
          break;
        }
        localOffset += diaries.length;
        if (diaries.length < _candidateBatchSize) {
          localHasMore = false;
        }

        for (final diary in diaries) {
          final source = _extractor.resolveMediaSource(diary);
          if (source == null || source.isEmpty || !localSources.add(source)) {
            continue;
          }
          appended.add(
            ExploreMediaItem(
              source: source,
              diaryId: diary.diaryId,
              updatedAt: diary.updatedAt,
            ),
          );
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _hasMore = localHasMore;
        _nextOffset = localOffset;
        _mediaItems.addAll(appended);
        _seenSources
          ..clear()
          ..addAll(localSources);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = context.l10n.autoT0197;
      });
    }
  }

  void _openViewer(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ExploreImageViewerPage(
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
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
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
