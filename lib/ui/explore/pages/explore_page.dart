import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/pages/diary_search_page.dart';
import '../../diaries/pages/edit_diary_page.dart';
import '../../widgets/page_header.dart';
import '../controllers/explore_page_controller.dart';
import '../models/explore_view_data.dart';
import 'explore_media_gallery_page.dart';
import '../providers/explore_providers.dart';
import '../sections/explore_content_section.dart';

/// 探索页壳层。
///
/// 页面职责：
/// - 监听数据 provider；
/// - 处理导航回调；
/// - 将聚合数据交给 sections 渲染。
class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key, required this.pageBackgroundColor});

  final Color pageBackgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diariesAsync = ref.watch(exploreDiariesProvider);
    final orderedTagsAsync = ref.watch(tagListProvider);
    final controller = const ExplorePageController();
    final headerHeight =
        MediaQuery.paddingOf(context).top + PageHeader.contentHeight;

    return Stack(
      children: <Widget>[
        Positioned.fill(child: ColoredBox(color: pageBackgroundColor)),
        SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: SizedBox(height: headerHeight + AppSpacing.m),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                sliver: diariesAsync.when(
                  loading:
                      () => const SliverToBoxAdapter(
                        child: _ExplorePageSkeleton(),
                      ),
                  error:
                      (error, stackTrace) => SliverToBoxAdapter(
                        child: _ExploreErrorCard(message: '$error'),
                      ),
                  data: (diaries) {
                    final orderedTagIds = orderedTagsAsync.maybeWhen(
                      data:
                          (tags) =>
                              tags.map((tag) => tag.id).toList(growable: false),
                      orElse: () => const <int>[],
                    );
                    final viewData = controller.buildViewData(
                      diaries,
                      now: DateTime.now(),
                      l10n: l10n,
                      orderedTagIds: orderedTagIds,
                    );
                    return SliverToBoxAdapter(
                      child: ExploreContentSection(
                        viewData: viewData,
                        controller: controller,
                        onOpenDiary: (diaryId) {
                          _openPreview(context, diaryId);
                        },
                        onOpenMediaGallery: () {
                          _openMediaGallery(context);
                        },
                        onOpenTagSearch: (tagUsage) {
                          _openTagSearch(context, tagUsage);
                        },
                        onCreateToday: () {
                          _openCreateToday(context);
                        },
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
          ),
        ),
        PageHeader(title: l10n.autoT0058),
      ],
    );
  }

  void _openPreview(BuildContext context, String diaryId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiaryPreviewPage(diaryId: diaryId),
      ),
    );
  }

  void _openCreateToday(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
      ),
    );
  }

  /// 从探索页标签云进入搜索页，并自动注入标签条件。
  void _openTagSearch(BuildContext context, ExploreTagUsage tagUsage) {
    Navigator.of(
      context,
    ).push(DiarySearchPage.buildRoute(initialTagIds: <int>{tagUsage.id}));
  }

  /// 打开全量媒体画廊页（分页加载）。
  void _openMediaGallery(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ExploreMediaGalleryPage()),
    );
  }
}

class _ExplorePageSkeleton extends StatelessWidget {
  const _ExplorePageSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.surfaceContainerHigh;
    return Column(
      children: <Widget>[
        Container(
          height: 66,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 168,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 132,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}

class _ExploreErrorCard extends StatelessWidget {
  const _ExploreErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.autoT0059,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
