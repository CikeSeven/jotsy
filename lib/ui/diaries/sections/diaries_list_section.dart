import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/relative_time_formatter.dart';
import '../widgets/diaries_empty_state.dart';
import '../viewmodels/diary_card_view_data.dart';
import '../widgets/diary_item_tag_row.dart';
import '../widgets/diary_selection_surface.dart';
import '../widgets/diary_swipe_action_item.dart';
import '../models/time_capsule.dart';
import '../pages/locked_diary_page.dart';
import '../widgets/energy_battery_indicator.dart';
import 'diary_head_section.dart';
import '../../widgets/expressive_entrance.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/expressive_image_frame.dart';
import '../../widgets/image_viewer_hero.dart';
import '../../widgets/launch_reveal.dart';
import '../../widgets/qweather_icon.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/list_item_presence.dart';

/// 日记页主列表区块。
///
/// 仅负责输出“日记内容本身”的 sliver，不再承载顶部标签条或独立滚动容器。
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
              child: DiariesEmptyState(
                onCreate: onCreate,
                isSearchResultEmpty: isSearchResultEmpty,
              ),
            ),
          ),
        ),
      );
    }

    // 瀑布流模式：双列卡片，卡片包含封面（如有）和摘要。
    if (layoutMode == DiaryLayoutMode.waterfall) {
      final waterfallLayoutSignature = _waterfallLayoutSignature(diaries);
      return SliverPadding(
        key: ValueKey<int>(waterfallLayoutSignature),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        sliver: SliverMasonryGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.s,
          crossAxisSpacing: AppSpacing.s,
          childCount: diaries.length,
          itemBuilder: (BuildContext context, int index) {
            final diary = diaries[index];
            return KeyedSubtree(
              key: ValueKey<String>('waterfall_${diary.diary.diaryId}'),
              child: LaunchReveal(
                slot: LaunchRevealSlot.content(index),
                child: _buildDiaryItem(context, diary: diary, compact: true),
              ),
            );
          },
        ),
      );
    }

    // 普通列表同样使用独立圆角表面；间距代替粗分割线，和瀑布流共享视觉层级。
    // 每项都挂启动编排槽位（结构恒定）；首屏之后的项落在同一槽位，编排结束
    // 后它们本就是落定态。
    return SliverList(
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        final diary = diaries[index];
        final isLast = index == diaries.length - 1;
        return KeyedSubtree(
          key: ValueKey<String>('list_${diary.diary.diaryId}'),
          child: LaunchReveal(
            slot: LaunchRevealSlot.content(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildDiaryItem(context, diary: diary, compact: false),
                  if (!isLast) const SizedBox(height: AppSpacing.s),
                ],
              ),
            ),
          ),
        );
      }, childCount: diaries.length),
    );
  }

  /// 根据当前瀑布流数据顺序生成稳定签名。
  /// 当条目排序变化（如编辑后更新时间变化）时，触发瀑布流 sliver 重建，避免旧布局残留空位。
  ///
  /// 性能说明：签名计算是 O(n) 遍历，列表较长时每帧重算会拖累滚动。
  /// 这里用静态单槽 memo 缓存“上一次列表引用 → 签名”：父级未替换 diaries 列表实例时
  /// （`identical` 命中）直接复用结果。父级每次重建若都生成新列表，则退化为原始计算，无副作用。
  static List<DiaryWithTags>? _lastSignatureSource;
  static int _lastSignatureValue = 0;

  int _waterfallLayoutSignature(List<DiaryWithTags> items) {
    if (identical(items, _lastSignatureSource)) {
      return _lastSignatureValue;
    }
    final value = _buildWaterfallLayoutSignature(items);
    _lastSignatureSource = items;
    _lastSignatureValue = value;
    return value;
  }

  int _buildWaterfallLayoutSignature(List<DiaryWithTags> items) {
    var hash = 17;
    for (final item in items) {
      hash = 37 * hash + item.diary.diaryId.hashCode;
      hash = 37 * hash + item.diary.updatedAt.millisecondsSinceEpoch.hashCode;
    }
    return hash;
  }

  Widget _buildDiaryItem(
    BuildContext context, {
    required DiaryWithTags diary,
    required bool compact,
  }) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final baseItemBackgroundColor = ExpressiveSurfaces.cardColor(colorScheme);
    final itemBackgroundColor = diary.diary.isPinned
        ? Color.alphaBlend(
            colorScheme.primary.withAlpha(14),
            baseItemBackgroundColor,
          )
        : baseItemBackgroundColor;
    final selected = selectedDiaryIds.contains(diary.diary.diaryId);
    // metadata、摘要与封面按 (diaryId, updatedAt) 缓存，滚动重建不再重复解析。
    final viewData = DiaryCardViewData.of(diary.diary);
    final previewCover = viewData.previewCover;
    final title = diary.diary.title.trim().isEmpty
        ? l10n.autoT0033
        : diary.diary.title;
    final preview = viewData.previewText;
    final hasVisibleTags = diary.tags.isNotEmpty && maxVisibleTags > 0;
    final capsuleState = TimeCapsuleState.fromFields(
      lockedAt: diary.diary.capsuleLockedAt,
      unlockAt: diary.diary.capsuleUnlockAt,
      now: DateTime.now(),
    );
    final isLockedCapsule = capsuleState.isLocked;
    // 封面所在的 context：点按卡片时从这里抓取已绘制的封面画面（只看封面子树，
    // 避免误抓天气图标等其他图片）。未解封胶囊的模糊封面不参与共享元素。
    final coverAnchor = ImageViewerHeroAnchor();
    final moodEmoji = viewData.moodEmoji;
    final weatherCode = viewData.weatherIconCode;

    return Builder(
      builder: (BuildContext _) {
        // 列表模式正文区域（顶部眉线/标题/标签/摘要/时间）结构。
        final detailContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部杂志眉线：日期 · 星期 + （置顶标签） + （天气/心情印章）
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 带封面时右侧文本列在 360dp 屏上只剩约 170dp，日期需可截断，
                // 否则与置顶徽章、天气心情印章同行时会溢出。外层 Expanded
                // 占满剩余宽度让印章贴右；内层日期是唯一弹性子项，只在空间
                // 不足时才截断（不能用 Flexible + Spacer，二者会平分空间）。
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.formatEyebrowDate(diary.diary.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontSize: 13,
                                color: diary.diary.isPinned
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant.withValues(
                                        alpha: 0.82,
                                      ),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.15,
                              ),
                        ),
                      ),
                      if (diary.diary.isPinned) ...[
                        const SizedBox(width: 6),
                        _buildPinnedBadge(context),
                      ],
                    ],
                  ),
                ),
                if (moodEmoji != null || weatherCode != null) ...[
                  const SizedBox(width: 6),
                  _buildMetaIndicators(
                    context,
                    moodEmoji: moodEmoji,
                    weatherCode: weatherCode,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // 标题行，多选态在右侧显示选中指示。
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18.5,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      height: 1.25,
                    ),
                  ),
                ),
                _buildSelectionMark(
                  context,
                  selected: selected,
                  compact: false,
                ),
              ],
            ),
            if (hasVisibleTags) ...[
              const SizedBox(height: 6),
              DiaryItemTagRow(tags: diary.tags, maxVisibleTags: maxVisibleTags),
            ],
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
                  height: 1.42,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  RelativeTimeFormatter.formatUpdatedAt(
                    updatedAt: diary.diary.updatedAt,
                    now: DateTime.now(),
                    l10n: l10n,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                    fontSize: 11.5,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],
        );

        // 瀑布流模式眉线行：日期星期 + 置顶胶囊。
        final compactEyebrow = Row(
          children: [
            Expanded(
              child: Text(
                l10n.formatEyebrowDate(diary.diary.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: diary.diary.isPinned
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (diary.diary.isPinned) ...[
              const SizedBox(width: 4),
              _buildPinnedBadge(context, compact: true),
            ],
          ],
        );

        // 瀑布流模式标题行，选中态在右侧显示勾选图标。
        final compactHeader = Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16.5,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                  height: 1.3,
                ),
              ),
            ),
            _buildSelectionMark(context, selected: selected, compact: true),
          ],
        );

        // 瀑布流文本区域（位于可选封面下方）。
        final compactTextContent = Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              compactEyebrow,
              const SizedBox(height: 5),
              compactHeader,
              if (hasVisibleTags) ...[
                const SizedBox(height: 5),
                DiaryItemTagRow(
                  tags: diary.tags,
                  maxVisibleTags: maxVisibleTags,
                ),
              ],
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
                    height: 1.36,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      RelativeTimeFormatter.formatUpdatedAt(
                        updatedAt: diary.diary.updatedAt,
                        now: DateTime.now(),
                        l10n: l10n,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.72,
                        ),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildMetaIndicators(
                    context,
                    moodEmoji: moodEmoji,
                    weatherCode: weatherCode,
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        );

        // 两种布局模式使用不同内容骨架，交互逻辑保持一致。
        // 普通列表模式（单列）封面保持在左侧，尺寸扩大至 116×116（大画幅展示，告别局促的 88dp 嵌套感）。
        Widget content = compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (previewCover != null) ...[
                    _buildCoverHeroSource(
                      diaryId: diary.diary.diaryId,
                      anchor: coverAnchor,
                      // 瀑布流封面贴着卡片顶边，上方两角由卡片裁圆。
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadii.card),
                      ),
                      child: _buildCoverPreview(
                        context,
                        previewCover,
                        width: double.infinity,
                        height: 140,
                        radius: 0,
                      ),
                    ),
                    Divider(
                      height: 0.6,
                      thickness: 0.6,
                      color: colorScheme.outlineVariant.withValues(
                        alpha: colorScheme.brightness == Brightness.light
                            ? 0.25
                            : 0.2,
                      ),
                    ),
                  ],
                  compactTextContent,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (previewCover != null) ...[
                    _buildCoverHeroSource(
                      diaryId: diary.diary.diaryId,
                      anchor: coverAnchor,
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      child: _buildCoverPreview(
                        context,
                        previewCover,
                        width: 116,
                        height: 116,
                        radius: 16,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(child: detailContent),
                ],
              );

        if (isLockedCapsule) {
          content = _buildLockedCapsuleContent(
            context,
            diary: diary,
            compact: compact,
            title: title,
            previewCover: previewCover,
            capsuleState: capsuleState,
          );
        }

        const itemRadius = AppRadii.card;

        // 统一点击交互：
        // - 选择模式下点击切换选中；
        // - 普通模式下点击进入详情（当前为预览页）；
        // - 长按强制选中。
        final item = DiarySelectionSurface(
          diaryId: diary.diary.diaryId,
          selected: selected,
          compact: compact,
          backgroundColor: itemBackgroundColor,
          borderRadius: itemRadius,
          isPinned: diary.diary.isPinned,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(itemRadius),
            // 水波纹与按压高亮叠在内容之上：画在内容下方透明 Material 上的墨水会被
            // 封面图、未解封胶囊的不透明主体盖住，按下去几乎看不到反馈。卡片内容
            // 不含可点击子控件，前景层不会吞掉其他交互；点击/长按语义仍并入
            // DiarySelectionSurface 的容器节点。
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    (compact || isLockedCapsule) ? 0 : 16,
                    (compact || isLockedCapsule) ? 0 : 14,
                    (compact || isLockedCapsule) ? 0 : 16,
                    (compact || isLockedCapsule) ? 0 : 14,
                  ),
                  child: content,
                ),
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: itemRadius > 0
                          ? BorderRadius.circular(itemRadius)
                          : null,
                      onTap: () {
                        if (isSelectionMode) {
                          onToggleSelection(diary.diary.diaryId, false);
                          return;
                        }
                        if (isLockedCapsule) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => LockedDiaryPage(
                                diaryId: diary.diary.diaryId,
                                initialDetail: diary,
                              ),
                            ),
                          );
                          return;
                        }
                        onOpenEditor(
                          diary,
                          coverAnchor.capture(
                            tag: diaryCoverHeroTag(diary.diary.diaryId),
                          ),
                        );
                      },
                      onLongPress: () {
                        // Android 上 InkWell 已经通过 Feedback.forLongPress
                        // 震动；iOS 不会，补一次以确认进入多选。
                        if (Theme.of(context).platform == TargetPlatform.iOS) {
                          unawaited(HapticFeedback.mediumImpact());
                        }
                        onToggleSelection(diary.diary.diaryId, true);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final animatedBaseItem = _buildAnimatedDiaryItem(
          context,
          diaryId: diary.diary.diaryId,
          child: item,
        );

        // 普通列表始终保留 Dismissible 根节点，避免进入选择模式时重建子树，
        // 从而让首次长按也能完整播放选中反馈；选择模式仅关闭滑动方向。
        if (!compact && onArchiveDiary != null) {
          final colorScheme = Theme.of(context).colorScheme;
          return DiarySwipeActionItem(
            diaryId: diary.diary.diaryId,
            enabled: !isSelectionMode,
            icon: swipeActionIcon,
            actionColor:
                swipeActionBackgroundColor ?? colorScheme.primaryContainer,
            actionIconColor:
                swipeActionIconColor ?? colorScheme.onPrimaryContainer,
            borderRadius: itemRadius,
            onSwiped: () => onArchiveDiary!(diary.diary.diaryId),
            child: animatedBaseItem,
          );
        }

        return animatedBaseItem;
      },
    );
  }

  /// 普通卡片的封面：作为预览页头图的共享元素来源，并把所在 context 记到
  /// [anchor] 供点按时抓取画面。
  Widget _buildCoverHeroSource({
    required String diaryId,
    required ImageViewerHeroAnchor anchor,
    required BorderRadius borderRadius,
    required Widget child,
  }) {
    return Builder(
      builder: (BuildContext coverContext) {
        anchor.context = coverContext;
        return ImageViewerHeroSource(
          tag: diaryCoverHeroTag(diaryId),
          borderRadius: borderRadius,
          child: child,
        );
      },
    );
  }

  /// 标题行末尾的选择标记。
  ///
  /// 选择模式下常驻：未选中为空心圆、选中为实心勾，切换选中只替换图标
  /// （[ExpressiveIconSwap]），标题可用宽度不变——此前勾选图标按需插入，会把
  /// 标题挤窄、重新折行，整张卡片跳一下。进出选择模式时槽位宽度经补间展开/收起
  /// （Align.widthFactor + ClipRect，结构恒定），减少动画时直接落位。
  Widget _buildSelectionMark(
    BuildContext context, {
    required bool selected,
    required bool compact,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isSelectionMode ? 1 : 0),
      duration: ExpressiveMotion.duration(context, itemTransitionDuration),
      curve: ExpressiveMotion.effects,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: compact ? 6 : 8,
          top: compact ? 0 : 2,
        ),
        child: ExpressiveIconSwap(
          switchKey: selected,
          child: FaIcon(
            selected
                ? FontAwesomeIcons.solidCircleCheck
                : FontAwesomeIcons.circle,
            size: compact ? 16 : 18,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      builder: (BuildContext context, double reveal, Widget? child) {
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topEnd,
            widthFactor: reveal,
            child: Opacity(opacity: reveal, child: child),
          ),
        );
      },
    );
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

  Widget _buildLockedCapsuleContent(
    BuildContext context, {
    required DiaryWithTags diary,
    required bool compact,
    required String title,
    required String? previewCover,
    required TimeCapsuleState capsuleState,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewData = DiaryCardViewData.of(diary.diary);
    final mood = viewData.moodEmoji;
    final weather = viewData.weather;
    final weatherIconCode = viewData.weatherIconCode;
    final rawEnergy = viewData.energyLevel;
    final energy = rawEnergy == null
        ? null
        : EnergyBatteryIndicator.normalizeValue(rawEnergy);
    final countdown = _countdownLabel(context, capsuleState);

    final clearMeta = Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        if (mood != null && mood.isNotEmpty)
          _buildCapsuleMetaPill(context, mood),
        if (weather != null && weather.isNotEmpty)
          _buildCapsuleMetaPill(
            context,
            weather,
            leading: QWeatherIcon(
              iconCode: weatherIconCode,
              weatherText: weather,
              size: 13,
            ),
          ),
        if (energy != null)
          _buildCapsuleMetaPill(
            context,
            EnergyBatteryIndicator.descriptionForValue(energy, context.l10n),
            leading: EnergyBatteryIndicator(value: energy, iconSize: 16),
          ),
      ],
    );

    // 未解封胶囊只渲染“占位条 + 低清模糊封面”，不再绘制真实正文：
    // 1) 隐私：真实文字即使被模糊，也会进入语义树被读屏读出；
    // 2) 性能：原先每张卡一个 BackdropFilter，需回读背景再模糊，屏上有多张
    //    时滚动卡顿；改为只对封面自身做 ImageFiltered，且封面按极小尺寸解码。
    final blurredBody = ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 12 : 14),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (previewCover != null)
                // clamp 采样边缘像素，避免模糊在封面四周采到透明而出现光晕；
                // ClipRect 防止模糊结果溢出到下方占位区。
                ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 6,
                      sigmaY: 6,
                      tileMode: TileMode.clamp,
                    ),
                    child: _buildCoverPreview(
                      context,
                      previewCover,
                      width: double.infinity,
                      height: compact ? 126 : 140,
                      radius: 0,
                      lowResolution: true,
                    ),
                  ),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: colorScheme.surfaceContainerHighest,
                child: _buildSealedTextPlaceholder(
                  context,
                  lineCount: compact ? 4 : 3,
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: ColoredBox(
              color: colorScheme.surface.withValues(alpha: 0.48),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: ShapeDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.82),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    FaIcon(
                      FontAwesomeIcons.lock,
                      size: 13,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        countdown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 11,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        12,
        compact ? 12 : 16,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FaIcon(
                FontAwesomeIcons.clock,
                size: 14,
                color: colorScheme.primary,
              ),
            ],
          ),
          if (clearMeta.children.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            clearMeta,
          ],
          const SizedBox(height: 10),
          blurredBody,
        ],
      ),
    );
  }

  /// 封存正文占位：用长短不一的圆角条示意“这里有文字”，不渲染任何真实内容。
  Widget _buildSealedTextPlaceholder(
    BuildContext context, {
    required int lineCount,
  }) {
    final barColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.16);
    const widthFactors = <double>[1, 0.88, 0.94, 0.62];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var line = 0; line < lineCount; line++) ...<Widget>[
          if (line > 0) const SizedBox(height: 9),
          FractionallySizedBox(
            widthFactor: line == lineCount - 1
                ? widthFactors.last
                : widthFactors[line % (widthFactors.length - 1)],
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const SizedBox(height: 10),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCapsuleMetaPill(
    BuildContext context,
    String label, {
    Widget? leading,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null) ...<Widget>[leading, const SizedBox(width: 5)],
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }

  String _countdownLabel(BuildContext context, TimeCapsuleState state) {
    final hours = state.remainingDuration.inHours;
    if (hours > 0 && hours < 24) {
      return context.l10n.timeCapsuleCountdownHours(hours.toString());
    }
    return context.l10n.timeCapsuleCountdownDays(
      state.remainingDays.toString(),
    );
  }

  /// 构建封面预览图（自动区分网络图与本地图）。
  /// 封面缩略图。
  ///
  /// 解码尺寸只限定一条边：同时给出宽高会按 ResizeImagePolicy.exact 把原图
  /// 压成卡片比例而变形，BoxFit.cover 负责绘制时裁切。
  /// - 宽度有限：按宽度解码；
  /// - 宽度为 infinity（瀑布流通栏封面）：用 LayoutBuilder 取实际列宽解码，
  ///   不再退化为只限高——那样竖图只解码出约 140dp 宽，拉伸到整列后发糊；
  /// - [lowResolution]：未解封胶囊的模糊封面，按极小尺寸解码，配合模糊既
  ///   省内存又无需高清细节。
  Widget _buildCoverPreview(
    BuildContext context,
    String imageSource, {
    double? width,
    required double height,
    required double radius,
    bool lowResolution = false,
  }) {
    final hasFiniteWidth = width != null && width.isFinite && width > 0;
    if (!hasFiniteWidth && !lowResolution) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final resolvedWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : null;
          return _buildCoverImage(
            context,
            imageSource,
            width: width,
            decodeWidth: resolvedWidth,
            height: height,
            radius: radius,
          );
        },
      );
    }
    return _buildCoverImage(
      context,
      imageSource,
      width: width,
      decodeWidth: lowResolution ? _sealedCoverDecodeWidth : width,
      height: height,
      radius: radius,
      lowResolution: lowResolution,
    );
  }

  /// 未解封胶囊封面的解码宽度（逻辑像素，不乘 dpr）：模糊后无需细节。
  static const double _sealedCoverDecodeWidth = 48;

  Widget _buildCoverImage(
    BuildContext context,
    String imageSource, {
    required double? width,
    required double? decodeWidth,
    required double height,
    required double radius,
    bool lowResolution = false,
  }) {
    final dpr = lowResolution ? 1.0 : MediaQuery.devicePixelRatioOf(context);
    final cacheWidth =
        decodeWidth != null && decodeWidth.isFinite && decodeWidth > 0
        ? (decodeWidth * dpr).round()
        : null;
    final cacheHeight = cacheWidth == null && height.isFinite && height > 0
        ? (height * dpr).round()
        : null;
    // 低清封面放大绘制时用双线性插值，避免出现马赛克块。
    final filterQuality = lowResolution
        ? FilterQuality.medium
        : FilterQuality.low;
    final trimmed = imageSource.trim();
    final uri = Uri.tryParse(trimmed);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    // 封面解码完成才出画面：用统一淡入替代“啪”地冒出，缓存命中（滚回已显示过
    // 的卡片）则直接显示，不会重复闪烁。
    final imageWidget = isNetwork
        ? Image.network(
            trimmed,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: filterQuality,
            frameBuilder: expressiveImageFrameBuilder,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) =>
                    _buildCoverFallback(context),
          )
        : Image.file(
            File(trimmed),
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: filterQuality,
            frameBuilder: expressiveImageFrameBuilder,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) =>
                    _buildCoverFallback(context),
          );

    final sized = SizedBox(width: width, height: height, child: imageWidget);
    // 通栏封面（radius 0）由外层卡片圆角裁切，无需再加一层裁剪。
    if (radius <= 0) {
      return sized;
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: sized);
  }

  /// 封面加载失败占位图（暗色模式自适应）。
  Widget _buildCoverFallback(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: FaIcon(
        FontAwesomeIcons.image,
        size: 20,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }

  /// 渲染日记卡片的情绪与天气指示器（精致微胶囊印章）。
  Widget _buildMetaIndicators(
    BuildContext context, {
    required String? moodEmoji,
    required String? weatherCode,
    bool compact = false,
  }) {
    if (moodEmoji == null && weatherCode == null) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5.5 : 7,
        vertical: compact ? 1.5 : 2.5,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: isLight ? 0.6 : 0.45,
        ),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: isLight ? 0.25 : 0.2,
          ),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (weatherCode != null) ...[
            QWeatherIcon(
              iconCode: weatherCode,
              size: compact ? 11.5 : 13,
              fallbackColor: colorScheme.onSurfaceVariant,
            ),
            if (moodEmoji != null) SizedBox(width: compact ? 3 : 4.5),
          ],
          if (moodEmoji != null)
            Text(
              moodEmoji,
              style: TextStyle(fontSize: compact ? 11 : 12.5, height: 1.1),
            ),
        ],
      ),
    );
  }

  /// 构建置顶微徽章胶囊。
  Widget _buildPinnedBadge(BuildContext context, {bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 1.5 : 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.22),
          width: 0.65,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.thumbtack,
            size: compact ? 8.5 : 9.5,
            color: colorScheme.primary,
          ),
          if (!compact) ...[
            const SizedBox(width: 3.5),
            Text(
              context.l10n.diaryPinnedBadge,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 打开日记：整条数据 + 从封面抓取的共享元素画面（可能为 null）。
typedef DiaryOpenCallback =
    void Function(DiaryWithTags diary, ImageViewerHero? coverHero);
