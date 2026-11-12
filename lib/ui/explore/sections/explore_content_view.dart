import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_features.dart';
import '../controllers/explore_computation_controller.dart';
import '../models/explore_computation_input.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../controllers/explore_module_actions.dart';
import '../models/explore_layout.dart';
import '../models/explore_module_config.dart';
import '../models/explore_module_id.dart';
import '../models/explore_period.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_module_menu.dart';
import '../widgets/explore_shared_widgets.dart';
import 'explore_module_builder.dart';
import 'explore_modules_view.dart';
import 'explore_period_bar.dart';

/// 探索页的内容区：统计范围条与按布局排好的卡片（探索页与自定义页的实时
/// 预览共用）。
///
/// 输入：日记概览、布局、统计范围、功能开关与几样附加数据；输出：一列卡片。
/// 哪些卡片出现：布局里显示的、功能开着的（[ExploreModuleSpec.isAvailable]），
/// 草稿箱只在有草稿时（[draftCount] > 0）。
///
/// 聚合会话经 [ExploreComputationController] 管理；大库在后台计算，条目解析
/// 结果按版本复用，完整聚合按输入的身份 /
/// 值缓存（概览列表身份、布局、范围、日期、语言、心情选项、标签顺序、这天的
/// 心情、照片数、一周首日与可见卡片），数据流没有新推送时重建不再重算。
/// 动作经外层的 [ExploreActionsScope]；外观经这里放的 [ExploreAppearanceScope]。
class ExploreContentView extends StatefulWidget {
  const ExploreContentView({
    super.key,
    required this.diaries,
    required this.layout,
    required this.period,
    required this.features,
    required this.moodOptions,
    required this.firstWeekday,
    this.orderedTagIds = const <int>[],
    this.dayMoods,
    this.photoCounts,
    this.draftCount = 0,
    this.now,
    this.onPeriodChanged,
    this.sliver = false,
  });

  final List<ExploreDiaryOverview> diaries;
  final ExploreLayout layout;
  final ExplorePeriod period;
  final AppFeatures features;
  final List<String> moodOptions;
  final int firstWeekday;
  final List<int> orderedTagIds;
  final Map<DateTime, DayMood>? dayMoods;
  final Map<String, int>? photoCounts;
  final int draftCount;

  /// 测试与预览注入的“现在”；null 时取当前时间。
  final DateTime? now;
  final ValueChanged<ExplorePeriod>? onPeriodChanged;

  /// 首页直接接入外层视口，卡片按需构建；设置页的有限预览保留盒布局。
  final bool sliver;

  /// 当前会出现在页面上的卡片（按布局顺序）。
  static List<ExploreModuleConfig> shownModules(
    ExploreLayout layout,
    AppFeatures features, {
    required int draftCount,
  }) => <ExploreModuleConfig>[
    for (final config in layout.modules)
      if (config.visible &&
          config.spec.isAvailable(features) &&
          !(config.id == ExploreModuleId.drafts && draftCount <= 0))
        config,
  ];

  @override
  State<ExploreContentView> createState() => _ExploreContentViewState();
}

class _ExploreContentViewState extends State<ExploreContentView> {
  final ExploreComputationController _computation =
      ExploreComputationController();

  @override
  void initState() {
    super.initState();
    _computation.addListener(_onComputed);
  }

  void _onComputed() => setState(() {});

  @override
  void dispose() {
    _computation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = widget.now ?? DateTime.now();
    final layout = widget.layout;
    final shown = ExploreContentView.shownModules(
      layout,
      widget.features,
      draftCount: widget.draftCount,
    );
    final data = _computation.resolve(
      ExploreComputationInput(
        diaries: widget.diaries,
        layout: layout,
        modules: {for (final config in shown) config.id},
        period: widget.period,
        now: now,
        firstWeekday: widget.firstWeekday,
        moodOptions: widget.moodOptions,
        l10n: l10n,
        orderedTagIds: widget.orderedTagIds,
        dayMoods: widget.dayMoods,
        photoCounts: widget.photoCounts,
      ),
    );
    final slots = <ExploreModuleSlot>[];
    if (data != null) {
      for (final config in shown) {
        final card = buildExploreModule(
          context,
          config: config,
          data: data,
          now: now,
          period: widget.period,
          moodOptions: widget.moodOptions,
        );
        if (card == null) continue;
        slots.add(
          ExploreModuleSlot(
            config: config,
            child: ExploreModuleMenu(id: config.id, child: card),
          ),
        );
      }
    }
    return ExploreAppearanceScope(
      appearance: layout.appearance,
      child: Builder(
        builder: (BuildContext context) {
          final look = ExploreAppearanceScope.of(context);
          final periodBar = layout.showPeriodBar
              ? Padding(
                  padding: EdgeInsets.only(bottom: look.cardGap),
                  child: ExplorePeriodBar(
                    period: widget.period,
                    onChanged: widget.onPeriodChanged,
                  ),
                )
              : null;
          final Widget content;
          if (_computation.error != null) {
            content = Text(l10n.autoT0059);
          } else if (data == null) {
            content = const DelayedLoadingIndicator();
          } else if (slots.isEmpty) {
            content = const _ExploreNoModulesCard();
          } else {
            content = ExploreModulesView(slots: slots, sliver: widget.sliver);
          }
          if (widget.sliver) {
            return SliverMainAxisGroup(
              slivers: <Widget>[
                if (periodBar != null) SliverToBoxAdapter(child: periodBar),
                if (content is ExploreModulesView)
                  content
                else
                  SliverToBoxAdapter(child: content),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[?periodBar, content],
          );
        },
      ),
    );
  }
}

/// 所有卡片都隐藏时的说明卡，带“自定义探索页”入口。
class _ExploreNoModulesCard extends StatelessWidget {
  const _ExploreNoModulesCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = ExploreActionsScope.of(context);
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const FaIcon(FontAwesomeIcons.compass, size: 20),
          const SizedBox(height: 10),
          ExploreInlineHint(
            message: l10n.exploreNoModules,
            actionLabel: l10n.exploreCustomize,
            onAction: actions.interactive ? actions.customize : null,
          ),
        ],
      ),
    );
  }
}
