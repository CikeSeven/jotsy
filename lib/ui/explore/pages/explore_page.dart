import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../calendar/providers/day_mood_providers.dart';
import '../../diaries/providers/diary_draft_providers.dart';
import '../../home/widgets/home_bar/home_top_bar_surface.dart';
import '../../notebooks/providers/notebook_insights_providers.dart';
import '../../settings/pages/explore_layout_page.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/expressive_entrance.dart';
import '../../widgets/page_header.dart';
import '../controllers/explore_module_actions.dart';
import '../models/explore_module_id.dart';
import '../models/explore_module_options.dart';
import '../models/explore_period.dart';
import '../providers/explore_providers.dart';
import '../providers/explore_settings_provider.dart';
import '../sections/explore_content_view.dart';

/// 探索页壳层。
///
/// 页面职责（AGENTS §3：页面只装配）：
/// - 监听数据与设置 provider（日记概览、标签顺序、心情选项、探索页布局与
///   统计范围、功能开关；这天的心情、照片数与草稿数只在用得到的卡片显示时
///   订阅）；
/// - 提供卡片动作（[ExplorePageActions]）与顶栏“自定义”入口；
/// - 把数据交给 [ExploreContentView] 排布卡片。
///
/// 骨架屏 → 内容 / 错误之间顶部对齐交叉淡入；内容区固定 key，数据刷新时
/// 不重复播放过渡。
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key, this.pageBackgroundColor, this.now});

  final Color? pageBackgroundColor;

  /// 测试注入的“现在”；null 时取当前时间。
  final DateTime? now;

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  late final ExplorePageActions _actions = ExplorePageActions(
    context: context,
    ref: ref,
    onCustomize: _openCustomize,
  );

  /// 打开探索页自定义（[focus] 给出时定位到这张卡）。
  void _openCustomize(ExploreModuleId? focus) {
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings == null) return;
    unawaited(
      Navigator.of(
        context,
      ).push(ExploreLayoutPage.route(settingsService: settings, focus: focus)),
    );
  }

  /// 范围条切换：只改行为里的统计范围，布局不动。
  void _setPeriod(ExplorePeriod period) {
    final service = ref.read(settingsServiceProvider).asData?.value;
    if (service == null) return;
    final settings = ref.read(exploreSettingsProvider);
    unawaited(
      saveExploreSettings(
        service,
        settings.withBehavior(settings.behavior.copyWith(period: period)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final diariesAsync = ref.watch(exploreDiariesProvider);
    final orderedTags = ref.watch(tagListProvider).value ?? const <Tag>[];
    final moodOptions =
        ref.watch(moodOptionsProvider).value ??
        SettingsService.defaultMoodOptions;
    final layout = ref.watch(exploreLayoutProvider);
    final period = ref.watch(explorePeriodProvider);
    final features = ref.watch(appFeaturesProvider);
    final firstWeekday = watchGoalFirstWeekday(context, ref);
    bool visible(ExploreModuleId id) {
      final config = layout.module(id);
      return config.visible && config.spec.isAvailable(features);
    }

    // 只在用得到的卡片显示时订阅附加数据：这天的心情（热力图、心情趋势）、
    // 照片数（看板选了“照片”）与草稿数（草稿箱卡）。
    final needsDayMoods =
        visible(ExploreModuleId.heatmap) ||
        (visible(ExploreModuleId.moodTrend) &&
            layout
                .module(ExploreModuleId.moodTrend)
                .toggle(ExploreOptions.moodTrendDayMoods));
    final dayMoods = needsDayMoods ? ref.watch(dayMoodsProvider).value : null;
    final needsPhotos =
        visible(ExploreModuleId.overview) &&
        layout
            .module(ExploreModuleId.overview)
            .multi(ExploreOptions.overviewMetrics)
            .contains(ExploreMetric.photos);
    final photoCounts = needsPhotos
        ? ref.watch(explorePhotoCountsProvider).value
        : null;
    final draftCount = visible(ExploreModuleId.drafts)
        ? ref.watch(diaryDraftCountProvider).value ?? 0
        : 0;
    final headerHeight =
        MediaQuery.paddingOf(context).top + PageHeader.contentHeight;
    // 玻璃底栏悬浮在内容之上时为底栏槽位高度（实色时为 0）：内容滚到胶囊
    // 下方，末尾多留这一段让最后一块完整露出。
    final floatingBarInset = MediaQuery.paddingOf(context).bottom;

    // 探索区域设了背景时页面底透明，露出首页画的背景（见 AppPagedBackground）。
    final pageBgColor =
        widget.pageBackgroundColor ?? AppPageBackdrop.pageColorOf(context);

    return ExploreActionsScope(
      actions: _actions,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: ColoredBox(color: pageBgColor)),
          SafeArea(
            top: false,
            bottom: false,
            // 宽窗口下内容居中到 960：用滚动视图的左右内边距居中，滚动条仍在
            // 窗口边缘。手机上留白就是原来的 16。
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  CustomScrollView(
                    slivers: <Widget>[
                      // 顶栏下缘到第一块内容固定留四个 Tab 统一的顶部间距
                      // （经典无背景时也留，改版前就是 12）。
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: headerHeight + kHomeTopContentGap,
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppContentWidth.gutter(
                            constraints.maxWidth,
                            AppContentWidth.explore,
                          ),
                        ),
                        sliver: SliverToBoxAdapter(
                          child: AnimatedSwitcher(
                            duration: ExpressiveMotion.duration(
                              context,
                              ExpressiveMotion.medium,
                            ),
                            switchInCurve: ExpressiveMotion.effects,
                            switchOutCurve: ExpressiveMotion.exit,
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
                                  alignment: Alignment.topCenter,
                                  children: <Widget>[
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                ),
                            child: diariesAsync.when(
                              // 本地查询通常很快：300ms 内保持空白、内容直接淡入，
                              // 不再先闪一帧骨架屏；慢查询才淡入骨架屏。
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
                              data: (diaries) => ExploreContentView(
                                key: const ValueKey<String>('explore_content'),
                                diaries: diaries,
                                layout: layout,
                                period: period,
                                features: features,
                                moodOptions: moodOptions,
                                firstWeekday: firstWeekday,
                                orderedTagIds: <int>[
                                  for (final tag in orderedTags) tag.id,
                                ],
                                dayMoods: dayMoods,
                                photoCounts: photoCounts,
                                draftCount: draftCount,
                                now: widget.now,
                                onPeriodChanged: _setPeriod,
                              ),
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
          ),
          PageHeader(
            title: l10n.autoT0058,
            contentMaxWidth: AppContentWidth.explore,
            actions: <Widget>[
              IconButton(
                tooltip: l10n.exploreCustomize,
                onPressed: () => _openCustomize(null),
                icon: const FaIcon(FontAwesomeIcons.sliders, size: 18),
              ),
            ],
          ),
        ],
      ),
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
    final content = Column(
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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
    // 玻璃时为内容玻璃；经典分支保持原样（这张卡本来就没有投影）。
    if (AppGlass.of(context).isGlass(AppGlassComponent.cards)) {
      return AppGlassSurface(
        component: AppGlassComponent.cards,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(12), child: content),
      );
    }
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
      child: content,
    );
  }
}
