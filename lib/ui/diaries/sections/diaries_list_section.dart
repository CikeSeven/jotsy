import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/settings_service.dart';
import '../controllers/diary_pointer_selection.dart';
import '../models/diary_card_style/diary_card_style.dart';
import '../viewmodels/diary_card_resolved_style.dart';
import '../widgets/diaries_empty_state.dart';
import '../widgets/diary_card/diary_card.dart';
import '../widgets/diary_card/diary_card_context_menu.dart';
import '../widgets/diary_card/diary_card_reading_ring.dart';
import '../widgets/diary_swipe_action_item.dart';
import '../widgets/diary_waterfall_sliver.dart';
import 'diary_head_section.dart';
import '../../widgets/expressive_entrance.dart';
import '../../widgets/launch_reveal.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/list_item_presence.dart';
import '../../widgets/glass/glass_reveal.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';

export '../widgets/diary_card/diary_card.dart' show DiaryOpenCallback;
export '../widgets/diary_card/diary_card_context_menu.dart'
    show DiaryCardMenuActions;
export '../controllers/diary_pointer_selection.dart' show DiarySelectionAnchor;

/// 日记页主列表区块。
///
/// 仅负责输出“日记内容本身”的 sliver（列表或瀑布流的排布、卡片间距、进出
/// 动画与滑动归档），不再承载顶部标签条或独立滚动容器。单张卡片的外观由
/// [DiaryCard] 按 [cardStyle] 绘制；样式每次 build 只解析一次
/// （[DiaryCardResolvedStyle]），卡片只做查表。
///
/// 玻璃卡片（`DiaryCardSurfaceStyle.isGlass`）不能放进 Opacity /
/// FadeTransition（背景模糊采不到页面，见 [GlassReveal]）：本区块里的启动
/// 编排与进出场在玻璃时改用 [GlassReveal]，宿主的整列表淡入改经
/// [revealProgress] 交进来逐项处理。实色卡片的结构与改版前相同。
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
    this.availableWidth,
    this.minWaterfallColumns = 0,
    this.readingRing = false,
    this.readingDiaryId,
    this.readingCardLocator,
    this.menuActions,
    this.selectionAnchor,
    this.revealProgress,
    this.commentCounts = const <String, int>{},
    this.belowCardBuilder,
  });

  /// 视图层已过滤/排序后的日记数据。
  final List<DiaryWithTags> diaries;

  /// 每篇的留言条数（键为日记业务 id）：卡片底栏的留言数。调用方读
  /// `diaryCommentCountsProvider`（留言功能关闭时为空表）；本区块不读
  /// provider，测试与设置页预览可以直接传入。
  final Map<String, int> commentCounts;

  /// 卡片下方的附加内容（搜索页“只命中留言”时那条命中的留言）；返回 null
  /// 表示这篇没有。附加内容与卡片一起进出场、一起左滑。
  final Widget? Function(BuildContext context, DiaryWithTags diary)?
  belowCardBuilder;

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

  /// 本区块实际可用的宽度（含卡片左右边距），卡片样式按它解析。由调用方在
  /// 滚动视图之外量好传入（`LayoutBuilder`），不在这里用 `SliverLayoutBuilder`：
  /// 后者的约束含滚动偏移，每个滚动帧都会重跑。null 时取屏宽，适用于铺满
  /// 整个窗口宽度的列表。
  final double? availableWidth;

  /// 瀑布流至少的列数（宽窗口按宽度加列）；0 表示只用卡片样式里的列数。
  final int minWaterfallColumns;

  /// 卡片是否带“正在阅读”环（宽窗口日记页双栏时）；为 false 时卡片结构
  /// 与改版前一致。
  final bool readingRing;

  /// 正在右栏阅读的日记 id：这张卡片显示阅读环（与多选的勾选互不影响）。
  final String? readingDiaryId;

  /// 正在阅读的卡片把位置记在这里，页面据此把它滚进视口。
  final DiaryReadingCardLocator? readingCardLocator;

  /// 桌面上卡片右键菜单的动作（见 [DiaryCardContextMenu]）；null 时不提供
  /// 右键菜单（日历、设置页预览）。手机上忽略。
  final DiaryCardMenuActions? menuActions;

  /// 桌面上 Ctrl / ⌘ + 点按切换勾选、Shift + 点按选范围（见
  /// [handleDiaryModifierTap]）的范围起点；null 时不支持修饰键多选（搜索、
  /// 日历这类没有多选的列表）。手机上忽略。
  final DiarySelectionAnchor? selectionAnchor;

  /// 整列表淡入的进度，由宿主代替外层的 `SliverFadeTransition` 交进来（日记
  /// 页筛选切换的刷新脉冲在卡片为玻璃时这样做）。非 null 时本区块逐项淡入：
  /// 玻璃卡片经 [GlassRevealTransition]，实色卡片、分组标题与空态经
  /// FadeTransition。null（默认）时不加任何包装，由宿主自己淡入。
  final Animation<double>? revealProgress;

  bool get _glass => cardStyle.surface.isGlass;

  /// 按 [revealProgress] 淡入一块不含玻璃的内容（分组标题、空态）。
  Widget _fadePlain(Widget child) {
    final progress = revealProgress;
    return progress == null
        ? child
        : FadeTransition(opacity: progress, child: child);
  }

  /// 按 [revealProgress] 淡入一个卡片列表项：玻璃不进透明度层。
  Widget _revealItem(Widget child) {
    final progress = revealProgress;
    if (progress == null) {
      return child;
    }
    return _glass
        ? GlassRevealTransition(progress: progress, child: child)
        : FadeTransition(opacity: progress, child: child);
  }

  /// 启动编排：实色照旧整块 Opacity；玻璃改用不套 Opacity 的
  /// [LaunchReveal.builder]，透明度经 [GlassReveal] 交给卡片表面。玻璃时
  /// 列表项里的分组标题不在玻璃之内、会随编排硬切——启动时首页总是停在
  /// 全部日记（没有分组标题），实际不会出现。
  Widget _launchReveal(int index, Widget child) {
    final slot = LaunchRevealSlot.content(index);
    if (!_glass) {
      return LaunchReveal(slot: slot, child: child);
    }
    return LaunchReveal.builder(
      slot: slot,
      builder: (BuildContext context, double opacity, Widget? child) =>
          GlassReveal(progress: opacity, child: child!),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = colorScheme.surface;

    // 空态：根据是否搜索场景展示不同文案。
    if (diaries.isEmpty) {
      return SliverToBoxAdapter(
        child: _fadePlain(
          ColoredBox(
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
        ),
      );
    }

    final isWaterfall = layoutMode == DiaryLayoutMode.waterfall;
    // 可用宽度由调用方量好传入（见 [availableWidth]）；没给时按铺满窗口
    // 处理，取屏宽。
    final resolved = DiaryCardResolvedStyle.resolve(
      style: cardStyle,
      mode: isWaterfall ? DiaryCardMode.waterfall : DiaryCardMode.list,
      theme: Theme.of(context),
      screenWidth: availableWidth ?? MediaQuery.sizeOf(context).width,
      textScale: MediaQuery.textScalerOf(context).scale(1),
      moodOptions: moodOptions,
      minColumns: isWaterfall ? minWaterfallColumns : 0,
      // 半透明 / 玻璃卡片的文字对比度按卡片实际叠在的颜色（页面背景色或
      // 背景图的估计色）计算；没有页面背景时就是主题页面底色。
      pageBackground: AppPageBackdrop.estimatedColorOf(context),
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
            child: _revealItem(
              _launchReveal(
                index,
                _buildDiaryItem(context, diary: diary, resolved: resolved),
              ),
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
          child: _launchReveal(
            index,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: modeStyle.sideMargin),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (sectionHeader != null) _fadePlain(sectionHeader),
                  _revealItem(
                    _buildDiaryItem(context, diary: diary, resolved: resolved),
                  ),
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
    final anchor = AppPlatform.isDesktop ? selectionAnchor : null;
    Widget card = DiaryCard(
      diary: diary,
      resolved: resolved,
      selected: selectedDiaryIds.contains(diaryId),
      isSelectionMode: isSelectionMode,
      maxVisibleTags: maxVisibleTags,
      onOpenEditor: onOpenEditor,
      // 长按勾选同样记作范围起点。
      onToggleSelection: anchor == null
          ? onToggleSelection
          : (String id, bool force) {
              anchor.id = id;
              onToggleSelection(id, force);
            },
      enableCoverHero: enableCoverHero,
      opensLockedCapsulePage: opensLockedCapsulePage,
      commentCount: commentCounts[diaryId] ?? 0,
      onTapIntercept: anchor == null
          ? null
          : (DiaryWithTags tapped) => handleDiaryModifierTap(
              order: <String>[for (final item in diaries) item.diary.diaryId],
              diaryId: tapped.diary.diaryId,
              anchor: anchor,
              toggle: onToggleSelection,
            ),
    );
    // 双栏时每张卡都包一层阅读环（结构恒定，换选时卡片不重建），环随卡片
    // 一起左滑；单栏时不包。
    if (readingRing) {
      card = DiaryCardReadingRing(
        diaryId: diaryId,
        active: diaryId == readingDiaryId,
        radius: resolved.cornerRadius,
        locator: readingCardLocator,
        child: card,
      );
    }
    // 桌面右键菜单包在最外层（含阅读环）；多选模式下不响应，结构不变。
    final actions = menuActions;
    if (actions != null && AppPlatform.isDesktop) {
      card = DiaryCardContextMenu(
        diary: diary,
        actions: actions,
        enabled: !isSelectionMode,
        child: card,
      );
    }
    final below = belowCardBuilder?.call(context, diary);
    if (below != null) {
      card = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[card, below],
      );
    }
    final animatedBaseItem = _buildAnimatedDiaryItem(
      context,
      diaryId: diaryId,
      child: card,
    );

    // 普通列表始终保留侧滑包装，避免进入选择模式时重建子树，从而让首次
    // 长按也能完整播放选中反馈；选择模式仅关闭滑动。未传 [onArchiveDiary]
    // （功能管理里关闭了侧滑归档）时不包。
    // 桌面上不提供左滑：鼠标拖动卡片会误触发归档，右键菜单已提供同样的操作。
    if (!resolved.compact && onArchiveDiary != null && !AppPlatform.isDesktop) {
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
      // 玻璃卡片的进出场走 GlassReveal，不进透明度层。
      glass: _glass,
      child: child,
    );
  }
}
