import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/pages/diary_search_page.dart';
import '../../diaries/controllers/diary_create_entry_flow.dart';
import '../../widgets/page_header.dart';
import '../controllers/explore_page_controller.dart';
import '../models/explore_view_data.dart';
import 'explore_media_gallery_page.dart';
import '../providers/explore_providers.dart';
import '../sections/explore_content_section.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/expressive_entrance.dart';

/// 探索页壳层。
///
/// 页面职责：
/// - 监听数据 provider；
/// - 处理导航回调；
/// - 将聚合数据交给 sections 渲染。
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key, this.pageBackgroundColor});

  final Color? pageBackgroundColor;

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final ExplorePageController _controller = const ExplorePageController();
  List<ExploreDiaryOverview>? _cachedDiariesRef;
  List<Tag>? _cachedTagsRef;
  String? _cachedLocaleName;
  String? _cachedDayKey;
  String? _cachedMoodOptionsRaw;
  ExploreViewData? _cachedViewData;

  ExploreViewData _resolveViewData({
    required List<ExploreDiaryOverview> diaries,
    required List<Tag> orderedTags,
    required AppLocalizations l10n,
    required String moodOptionsRaw,
    required List<String> moodOptions,
  }) {
    final day = DateUtils.dateOnly(DateTime.now());
    final dayKey = '${day.year}-${day.month}-${day.day}';
    final shouldRebuild =
        _cachedViewData == null ||
        !identical(diaries, _cachedDiariesRef) ||
        !identical(orderedTags, _cachedTagsRef) ||
        _cachedLocaleName != l10n.localeName ||
        _cachedDayKey != dayKey ||
        _cachedMoodOptionsRaw != moodOptionsRaw;

    if (!shouldRebuild) {
      return _cachedViewData!;
    }

    final orderedTagIds = orderedTags
        .map((tag) => tag.id)
        .toList(growable: false);
    _cachedViewData = _controller.buildViewData(
      diaries,
      now: DateTime.now(),
      l10n: l10n,
      orderedTagIds: orderedTagIds,
      moodOptions: moodOptions,
    );
    _cachedDiariesRef = diaries;
    _cachedTagsRef = orderedTags;
    _cachedLocaleName = l10n.localeName;
    _cachedDayKey = dayKey;
    _cachedMoodOptionsRaw = moodOptionsRaw;
    return _cachedViewData!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final diariesAsync = ref.watch(exploreDiariesProvider);
    final orderedTagsAsync = ref.watch(tagListProvider);
    final moodOptionsAsync = ref.watch(moodOptionsProvider);
    final moodOptions = moodOptionsAsync.maybeWhen(
      data: (options) => options,
      orElse: () => SettingsService.defaultMoodOptions,
    );
    final moodOptionsRaw = moodOptions.join('\u{1F}');
    final headerHeight =
        MediaQuery.paddingOf(context).top + PageHeader.contentHeight;
    // 玻璃底栏悬浮在内容之上时为底栏槽位高度（实色时为 0）：内容滚到胶囊
    // 下方，末尾多留这一段让最后一块完整露出。
    final floatingBarInset = MediaQuery.paddingOf(context).bottom;

    final pageBgColor =
        widget.pageBackgroundColor ?? Theme.of(context).colorScheme.surface;

    return Stack(
      children: <Widget>[
        Positioned.fill(child: ColoredBox(color: pageBgColor)),
        SafeArea(
          top: false,
          bottom: false,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: SizedBox(height: headerHeight + AppSpacing.m),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                // 骨架屏 → 内容 / 错误之间顶部对齐交叉淡入，不再硬切；内容
                // 区使用固定 key，数据刷新时不会重复播放过渡。
                sliver: SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.medium,
                    ),
                    switchInCurve: ExpressiveMotion.effects,
                    switchOutCurve: ExpressiveMotion.exit,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[...previousChildren, ?currentChild],
                    ),
                    child: diariesAsync.when(
                      // 本地查询通常很快：300ms 内保持空白、内容直接淡入，不再先
                      // 闪一帧骨架屏、又在 250ms 交叉淡入里残留成重影；慢查询
                      // 才淡入骨架屏。
                      loading: () => DelayedLoadingGate(
                        key: const ValueKey<String>('explore_skeleton'),
                        loading: true,
                        builder: (context, showSkeleton) => showSkeleton
                            ? const ExpressiveEntrance(
                                offset: Offset.zero,
                                duration: ExpressiveMotion.fast,
                                child: _ExplorePageSkeleton(),
                              )
                            : const SizedBox.shrink(),
                      ),
                      error: (error, stackTrace) => _ExploreErrorCard(
                        key: const ValueKey<String>('explore_error'),
                        message: '$error',
                      ),
                      data: (diaries) {
                        final orderedTags = orderedTagsAsync.maybeWhen(
                          data: (tags) => tags,
                          orElse: () => const <Tag>[],
                        );
                        final viewData = _resolveViewData(
                          diaries: diaries,
                          orderedTags: orderedTags,
                          l10n: l10n,
                          moodOptionsRaw: moodOptionsRaw,
                          moodOptions: moodOptions,
                        );
                        return ExploreContentSection(
                          key: const ValueKey<String>('explore_content'),
                          viewData: viewData,
                          controller: _controller,
                          onOpenDiary: (diaryId) {
                            _openPreview(
                              context,
                              diaryId,
                              // 只有“那年今日”会打开日记：在这几篇里左右翻。
                              sequence: DiaryPreviewSequence(
                                ids: <String>[
                                  for (final item in viewData.onThisDayDiaries)
                                    item.diaryId,
                                ],
                              ),
                            );
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
                        );
                      },
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: 12 + floatingBarInset),
              ),
            ],
          ),
        ),
        PageHeader(title: l10n.autoT0058),
      ],
    );
  }

  void _openPreview(
    BuildContext context,
    String diaryId, {
    DiaryPreviewSequence? sequence,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiaryPreviewPage(diaryId: diaryId, sequence: sequence),
      ),
    );
  }

  /// 与首页 FAB 同一条新建流程：有草稿时先弹草稿选择面板。
  void _openCreateToday(BuildContext context) {
    unawaited(runDiaryCreateEntryFlow(context, ref));
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
  const _ExploreErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ExpressiveSurfaces.cardColor(colorScheme),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ExpressiveSurfaces.cardBorderColor(colorScheme),
          width: 0.8,
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
