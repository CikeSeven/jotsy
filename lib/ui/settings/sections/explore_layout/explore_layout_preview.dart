import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/app_breakpoints.dart';
import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/app_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../diaries/providers/diary_draft_providers.dart';
import '../../../explore/controllers/explore_comment_stats.dart';
import '../../../explore/controllers/explore_module_actions.dart';
import '../../../explore/providers/explore_providers.dart';
import '../../../explore/sections/explore_content_view.dart';
import '../../../notebooks/providers/notebook_insights_providers.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/explore_layout_editor_controller.dart';
import '../../providers/app_features_provider.dart';
import '../../widgets/style_editor/style_preview_background.dart';
import 'explore_layout_samples.dart';

/// 自定义页的实时预览：用真实卡片（[ExploreContentView]）按正在编辑的布局
/// 渲染，可以滚动，点按不跳转（[ExploreModuleActions.inert]）。
///
/// 数据来源可在工具条切换：自己的日记（与探索页同一份概览）或示例数据；
/// 草稿箱卡与探索页一样只在有草稿时出现。示例数据模式下“最近的留言”卡片
/// 的两个 provider 在预览里换成示例留言（嵌套 [ProviderScope]，只作用于预览
/// 这棵子树）；其余关联卡片照旧读自己模块的数据。预览在自己的明暗
/// 主题之内画探索区域的背景（[StylePreviewBackground]）。
class ExploreLayoutPreview extends ConsumerStatefulWidget {
  const ExploreLayoutPreview({
    super.key,
    required this.controller,
    this.showToolbar = true,
    this.bottomPadding = 0,
  });

  final ExploreLayoutEditorController controller;
  final bool showToolbar;
  final double bottomPadding;

  @override
  ConsumerState<ExploreLayoutPreview> createState() =>
      _ExploreLayoutPreviewState();
}

class _ExploreLayoutPreviewState extends ConsumerState<ExploreLayoutPreview> {
  List<ExploreDiaryOverview>? _samples;
  ExploreCommentSamples? _commentSamples;
  String? _samplesKey;

  /// 示例日记与挂在它们上面的示例留言，按语言、日期与心情选项缓存（同一天
  /// 重建预览不重新生成）。
  (List<ExploreDiaryOverview>, ExploreCommentSamples) _samplesFor(
    AppLocalizations l10n,
    List<String> moodOptions,
  ) {
    final now = DateTime.now();
    final key =
        '${l10n.localeName}|${now.year}-${now.month}-${now.day}|'
        '${moodOptions.join()}';
    if (_samples == null || key != _samplesKey) {
      _samplesKey = key;
      final samples = _samples = buildExploreLayoutSamples(
        l10n,
        now: now,
        moodOptions: moodOptions,
      );
      _commentSamples = buildExploreCommentSamples(
        l10n,
        now: now,
        diaries: samples,
        moodOptions: moodOptions,
      );
    }
    return (_samples!, _commentSamples!);
  }

  ThemeData _themeFor(ThemeData appTheme, Brightness brightness) {
    if (brightness == appTheme.brightness) return appTheme;
    return SeededThemeCache.of(
      Color(widget.controller.settingsService.themeSeedColorValue),
      brightness,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final moodOptions =
        ref.watch(moodOptionsProvider).value ??
        SettingsService.defaultMoodOptions;
    final mine = ref.watch(exploreDiariesProvider).value;
    final samples = controller.useSamples || mine == null
        ? _samplesFor(l10n, moodOptions)
        : null;
    final diaries = samples?.$1 ?? mine!;
    final orderedTags = ref.watch(tagListProvider).value ?? const <Tag>[];
    final appTheme = Theme.of(context);
    final previewTheme = _themeFor(
      appTheme,
      controller.previewBrightness ?? appTheme.brightness,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showToolbar)
          ExploreLayoutPreviewToolbar(controller: controller),
        Expanded(
          child: Theme(
            data: previewTheme,
            child: ClipRect(
              child: StylePreviewBackground(
                child: Builder(
                  builder: (BuildContext context) => Material(
                    color: AppPageBackdrop.pageColorOf(context),
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints box) =>
                          ListView(
                            primary: false,
                            padding: EdgeInsets.fromLTRB(
                              AppContentWidth.gutter(
                                box.maxWidth,
                                AppContentWidth.explore,
                              ),
                              12,
                              AppContentWidth.gutter(
                                box.maxWidth,
                                AppContentWidth.explore,
                              ),
                              12 + widget.bottomPadding,
                            ),
                            children: <Widget>[
                              _withSampleComments(
                                samples?.$2,
                                ExploreActionsScope(
                                  actions: ExploreModuleActions.inert,
                                  child: ExploreContentView(
                                    diaries: diaries,
                                    layout: controller.style,
                                    period: controller.period,
                                    features: ref.watch(appFeaturesProvider),
                                    moodOptions: moodOptions,
                                    firstWeekday: watchGoalFirstWeekday(
                                      context,
                                      ref,
                                    ),
                                    orderedTagIds: <int>[
                                      for (final tag in orderedTags) tag.id,
                                    ],
                                    draftCount:
                                        ref
                                            .watch(diaryDraftCountProvider)
                                            .value ??
                                        0,
                                    onPeriodChanged: controller.setPeriod,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 示例数据模式（[comments] 非空）下把“最近的留言”卡片的数据换成示例留言。
///
/// 只覆盖这两个 provider，其余仍取外层的；切换数据来源时这一层出现或消失，
/// 预览的卡片随之重建（数据本来就整份换了）。真实数据模式不加这一层，卡片照常
/// 订阅留言表（只在留言功能开启且卡片显示时）。
Widget _withSampleComments(ExploreCommentSamples? comments, Widget child) {
  if (comments == null) return child;
  return ProviderScope(
    overrides: [
      exploreRecentCommentsProvider.overrideWithValue(
        AsyncData<List<DiaryCommentSummary>>(comments.recent),
      ),
      exploreCommentStatsProvider.overrideWithValue(
        AsyncData<ExploreCommentStats>(comments.stats),
      ),
    ],
    child: child,
  );
}

/// 预览工具条：数据来源（我的数据 / 示例数据）与预览明暗。
class ExploreLayoutPreviewToolbar extends StatelessWidget {
  const ExploreLayoutPreviewToolbar({super.key, required this.controller});

  final ExploreLayoutEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brightness =
        controller.previewBrightness ?? Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ExpressiveButtonGroup<bool>(
              minSegmentWidth: 96,
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(l10n.exploreLayoutPreviewMine),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(l10n.exploreLayoutPreviewSample),
                ),
              ],
              selected: <bool>{controller.useSamples},
              onSelectionChanged: (Set<bool> selection) =>
                  controller.useSamples = selection.single,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: isLight
                ? l10n.styleEditorPreviewDark
                : l10n.styleEditorPreviewLight,
            onPressed: () => controller.previewBrightness = isLight
                ? Brightness.dark
                : Brightness.light,
            icon: FaIcon(
              isLight ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}
