import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../models/diary_card_style/diary_card_style.dart';
import '../viewmodels/diary_card_resolved_style.dart';
import '../widgets/diaries_empty_state.dart';
import '../widgets/diary_card/diary_card.dart';
import '../widgets/diary_swipe_action_item.dart';
import '../widgets/diary_waterfall_sliver.dart';
import 'diary_head_section.dart';
import '../../widgets/expressive_entrance.dart';
import '../../widgets/launch_reveal.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/list_item_presence.dart';

export '../widgets/diary_card/diary_card.dart' show DiaryOpenCallback;

/// 日记页主列表区块。
///
/// 仅负责输出“日记内容本身”的 sliver（列表或瀑布流的排布、卡片间距、进出
/// 动画与滑动归档），不再承载顶部标签条或独立滚动容器。单张卡片的外观由
/// [DiaryCard] 按 [cardStyle] 绘制；样式每次 build 只解析一次
/// （[DiaryCardResolvedStyle]），卡片只做查表。
class DiariesListSection extends StatelessWidget {
  /// 单条日记项进入/退出列表时的过渡时长。日记页的隐藏/出现计时器复用
  /// 同一常量，保证动画结束与状态收尾同步。
  static const Duration itemTransitionDuration = ExpressiveMotion.medium;

  const DiariesListSection({
    super.key,
    required this.diaries,
    required this.layoutMode,
    required this.selectedDiaryIds,
    required this.isSelectionMode,
    required this.maxVisibleTags,
    this.pendingHideDiaryIds = const <String>{},
    this.appearingDiaryIds = const <String>{},
    required this.onCreate,
    required this.onOpenEditor,
    required this.onToggleSelection,
    this.onArchiveDiary,
    this.swipeActionIcon = FontAwesomeIcons.boxArchive,
    this.swipeActionBackgroundColor,
    this.swipeActionIconColor,
    this.isSearchResultEmpty = false,
    this.emptyState,
    this.cardStyle = DiaryCardStyle.defaults,
    this.moodOptions = SettingsService.defaultMoodOptions,
    this.enableCoverHero = true,
    this.opensLockedCapsulePage = true,
    this.sectionHeaderBuilder,
  });

  /// 视图层已过滤/排序后的日记数据。
  final List<DiaryWithTags> diaries;

  /// 列表布局模式：列表 or 瀑布流。
  final DiaryLayoutMode layoutMode;

  /// 当前被选中的日记 ID 集合。
  final Set<String> selectedDiaryIds;
  final bool isSelectionMode;

  /// 页面装配层传入的已规范化标签显示上限。
  final int maxVisibleTags;

  /// 标记“正在收起隐藏”的日记项集合。
  final Set<String> pendingHideDiaryIds;

  /// 标记“正在出现动画”的日记项集合。
  final Set<String> appearingDiaryIds;
  final VoidCallback onCreate;

  /// 普通模式点击卡片：传入整条数据（预览页可直接用它渲染首帧）与从封面抓取
  /// 的画面（预览页头图以它为共享元素落点，无封面或减少动画时为 null）。
  final DiaryOpenCallback onOpenEditor;
  final void Function(String noteId, bool forceSelect) onToggleSelection;
  final ValueChanged<String>? onArchiveDiary;
  final FaIconData swipeActionIcon;
  final Color? swipeActionBackgroundColor;
  final Color? swipeActionIconColor;

  /// 空列表时是否处于“搜索结果为空”语义。
  final bool isSearchResultEmpty;

  /// 自定义空状态（如日记本里的“这本还空着”）；null 时用默认空状态。
  final Widget? emptyState;

  /// 用户的卡片样式；默认即改版前的经典外观。
  final DiaryCardStyle cardStyle;

  /// 心情配置：卡片按“心情色”着色时用它把心情换算成档位。
  final List<String> moodOptions;

  /// 封面是否作为预览页头图的共享元素来源（设置页预览关闭）。
  final bool enableCoverHero;

  /// 点按未解封胶囊是否进入封存页（设置页预览关闭）。
  final bool opensLockedCapsulePage;

  /// 列表布局里第 index 篇卡片上方的分组标题（如日记本书序的章节分隔行），
  /// 返回 null 表示这篇上方没有。只在列表布局生效，瀑布流忽略；默认 null，
  /// 其他列表（归档、搜索、全部日记）不受影响。
  final Widget? Function(BuildContext context, int index)? sectionHeaderBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = colorScheme.surface;

    // 空态：根据是否搜索场景展示不同文案。
    if (diaries.isEmpty) {
      return SliverToBoxAdapter(
        child: ColoredBox(
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.m,
            ),
            // 最后一篇被归档/删除、或首屏没有日记时淡入上移，而不是硬切出现。
            child: ExpressiveEntrance(
              child:
                  emptyState ??
                  DiariesEmptyState(
                    onCreate: onCreate,
                    isSearchResultEmpty: isSearchResultEmpty,
                  ),
            ),
          ),
        ),
      );
    }

    final isWaterfall = layoutMode == DiaryLayoutMode.waterfall;
    // 屏宽取 MediaQuery 而不是 SliverLayoutBuilder：后者的约束含滚动偏移，
    // 每个滚动帧都会重跑。四个调用方都是全宽页面，屏宽即可用宽度。
    final resolved = DiaryCardResolvedStyle.resolve(
      style: cardStyle,
      mode: isWaterfall ? DiaryCardMode.waterfall : DiaryCardMode.list,
      theme: Theme.of(context),
      screenWidth: MediaQuery.sizeOf(context).width,
      textScale: MediaQuery.textScalerOf(context).scale(1),
      moodOptions: moodOptions,
    );
    final modeStyle = resolved.modeStyle;

    // 瀑布流模式：多列卡片，卡片包含封面（如有）和摘要。
    if (isWaterfall) {
      return DiaryWaterfallSliver(
        diaries: diaries,
        columns: resolved.columns,
        sideMargin: modeStyle.sideMargin,
        cardGap: modeStyle.cardGap,
        itemBuilder: (BuildContext context, int index) {
          final diary = diaries[index];
          return KeyedSubtree(
            key: ValueKey<String>('waterfall_${diary.diary.diaryId}'),
            child: LaunchReveal(
              slot: LaunchRevealSlot.content(index),
              child: _buildDiaryItem(context, diary: diary, resolved: resolved),
            ),
          );
        },
      );
    }

    // 普通列表同样使用独立圆角表面；间距代替粗分割线，和瀑布流共享视觉层级。
    // 每项都挂启动编排槽位（结构恒定）；首屏之后的项落在同一槽位，编排结束
    // 后它们本就是落定态。
    return SliverList(
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        final diary = diaries[index];
        final isLast = index == diaries.length - 1;
        final sectionHeader = sectionHeaderBuilder?.call(context, index);
        return KeyedSubtree(
          key: ValueKey<String>('list_${diary.diary.diaryId}'),
          child: LaunchReveal(
            slot: LaunchRevealSlot.content(index),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: modeStyle.sideMargin),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ?sectionHeader,
                  _buildDiaryItem(context, diary: diary, resolved: resolved),
                  if (!isLast) SizedBox(height: modeStyle.cardGap),
                ],
              ),
            ),
          ),
        );
      }, childCount: diaries.length),
    );
  }

  Widget _buildDiaryItem(
    BuildContext context, {
    required DiaryWithTags diary,
    required DiaryCardResolvedStyle resolved,
  }) {
    final diaryId = diary.diary.diaryId;
    final card = DiaryCard(
      diary: diary,
      resolved: resolved,
      selected: selectedDiaryIds.contains(diaryId),
      isSelectionMode: isSelectionMode,
      maxVisibleTags: maxVisibleTags,
      onOpenEditor: onOpenEditor,
      onToggleSelection: onToggleSelection,
      enableCoverHero: enableCoverHero,
      opensLockedCapsulePage: opensLockedCapsulePage,
    );
    final animatedBaseItem = _buildAnimatedDiaryItem(
      context,
      diaryId: diaryId,
      child: card,
    );

    // 普通列表始终保留 Dismissible 根节点，避免进入选择模式时重建子树，
    // 从而让首次长按也能完整播放选中反馈；选择模式仅关闭滑动方向。
    if (!resolved.compact && onArchiveDiary != null) {
      final colorScheme = Theme.of(context).colorScheme;
      return DiarySwipeActionItem(
        diaryId: diaryId,
        enabled: !isSelectionMode,
        icon: swipeActionIcon,
        actionColor: swipeActionBackgroundColor ?? colorScheme.primaryContainer,
        actionIconColor: swipeActionIconColor ?? colorScheme.onPrimaryContainer,
        borderRadius: resolved.cornerRadius,
        onSwiped: () => onArchiveDiary!(diaryId),
        child: animatedBaseItem,
      );
    }

    return animatedBaseItem;
  }

  Widget _buildAnimatedDiaryItem(
    BuildContext context, {
    required String diaryId,
    required Widget child,
  }) {
    final transitionDuration = ExpressiveMotion.duration(
      context,
      itemTransitionDuration,
    );
    final isExiting = pendingHideDiaryIds.contains(diaryId);
    final isAppearing = appearingDiaryIds.contains(diaryId);
    return ListItemPresence(
      key: ValueKey<String>('presence_$diaryId'),
      visible: !isExiting,
      appearing: isAppearing && !isExiting,
      duration: transitionDuration,
      child: child,
    );
  }
}
