import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/pages/diary_search_page.dart';
import '../../diaries/pages/edit_diary_page.dart';
import '../../widgets/glass_page_header.dart';
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
    final backdropTone = diariesAsync.maybeWhen(
      data:
          (diaries) =>
              controller.resolveBackdropTone(diaries, now: DateTime.now()),
      orElse: () => ExploreBackdropTone.warm,
    );
    final headerHeight =
        MediaQuery.paddingOf(context).top + GlassPageHeader.contentHeight;

    return Stack(
      children: <Widget>[
        Positioned.fill(child: ColoredBox(color: pageBackgroundColor)),
        Positioned.fill(child: _ExploreAmbientBackdrop(tone: backdropTone)),
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
        GlassPageHeader(title: l10n.autoT0058),
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
    final color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
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

/// 探索页背景氛围层：
/// 在纯色底上增加柔和光斑，让毛玻璃卡片的“透感”更明显。
class _ExploreAmbientBackdrop extends StatelessWidget {
  const _ExploreAmbientBackdrop({required this.tone});

  final ExploreBackdropTone tone;

  @override
  Widget build(BuildContext context) {
    final isWarm = tone == ExploreBackdropTone.warm;
    final colors =
        isWarm
            ? const <Color>[
              Color(0xFFFFC48D),
              Color(0xFFFFA9B8),
              Color(0xFFFFDDA3),
            ]
            : const <Color>[
              Color(0xFF8DB7FF),
              Color(0xFF96D0FF),
              Color(0xFFAAB8FF),
            ];
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          _buildBlurBlob(
            alignment: const Alignment(-1.25, -0.68),
            diameter: 260,
            color: colors[0].withValues(alpha: 0.24),
          ),
          _buildBlurBlob(
            alignment: const Alignment(1.20, -0.10),
            diameter: 230,
            color: colors[1].withValues(alpha: 0.20),
          ),
          _buildBlurBlob(
            alignment: const Alignment(-0.86, 0.92),
            diameter: 220,
            color: colors[2].withValues(alpha: 0.20),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurBlob({
    required Alignment alignment,
    required double diameter,
    required Color color,
  }) {
    return Align(
      alignment: alignment,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
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
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
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
