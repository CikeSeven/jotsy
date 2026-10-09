import 'dart:convert';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/relative_time_formatter.dart';
import '../widgets/diaries_empty_state.dart';
import '../widgets/diary_item_tag_row.dart';
import '../widgets/diary_selection_surface.dart';
import '../models/time_capsule.dart';
import '../pages/locked_diary_page.dart';
import '../widgets/energy_battery_indicator.dart';
import 'diary_head_section.dart';
import '../../widgets/qweather_icon.dart';

/// 日记页主列表区块。
///
/// 仅负责输出“日记内容本身”的 sliver，不再承载顶部标签条或独立滚动容器。
class DiariesListSection extends StatelessWidget {
  /// 单条日记项进入/退出列表时的过渡时长。
  static const Duration _itemTransitionDuration = Duration(milliseconds: 220);
  static const int _maxPreviewCoverCacheEntries = 600;
  static final Map<String, String?> _previewCoverCache = <String, String?>{};
  static final ListQueue<String> _previewCoverCacheOrder = ListQueue<String>();

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
  final void Function(String diaryId) onOpenEditor;
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
            child: DiariesEmptyState(
              onCreate: onCreate,
              isSearchResultEmpty: isSearchResultEmpty,
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
              child: _buildDiaryItem(context, diary: diary, compact: true),
            );
          },
        ),
      );
    }

    // 普通列表同样使用独立圆角表面；间距代替粗分割线，和瀑布流共享视觉层级。
    return SliverList(
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        final diary = diaries[index];
        final isLast = index == diaries.length - 1;
        return KeyedSubtree(
          key: ValueKey<String>('list_${diary.diary.diaryId}'),
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
    final previewCover = _resolvePreviewCover(diary.diary);
    final title = diary.diary.title.trim().isEmpty
        ? l10n.autoT0033
        : diary.diary.title;
    final preview = diary.diary.contentText.replaceAll('\n', ' ').trim();
    final hasVisibleTags = diary.tags.isNotEmpty && maxVisibleTags > 0;
    final capsuleState = TimeCapsuleState.fromFields(
      lockedAt: diary.diary.capsuleLockedAt,
      unlockAt: diary.diary.capsuleUnlockAt,
      now: DateTime.now(),
    );
    final isLockedCapsule = capsuleState.isLocked;
    final contextMeta = _extractContextMetadata(diary.diary.metadata);
    final moodEmoji =
        (contextMeta['mood'] is String &&
            (contextMeta['mood'] as String).trim().isNotEmpty)
        ? (contextMeta['mood'] as String).trim()
        : null;
    final weatherCode =
        (contextMeta['weather_icon_code'] is String &&
            (contextMeta['weather_icon_code'] as String).trim().isNotEmpty)
        ? (contextMeta['weather_icon_code'] as String).trim()
        : null;

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
                Text(
                  l10n.formatEyebrowDate(diary.diary.createdAt),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 13,
                    color: diary.diary.isPinned
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.15,
                  ),
                ),
                if (diary.diary.isPinned) ...[
                  const SizedBox(width: 6),
                  _buildPinnedBadge(context),
                ],
                if (moodEmoji != null || weatherCode != null) ...[
                  const Spacer(),
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
                if (selected) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: FaIcon(
                      FontAwesomeIcons.solidCircleCheck,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
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
            if (selected) ...[
              const SizedBox(width: 6),
              FaIcon(
                FontAwesomeIcons.solidCircleCheck,
                size: 16,
                color: colorScheme.primary,
              ),
            ],
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
                    _buildCoverPreview(
                      context,
                      previewCover,
                      width: double.infinity,
                      height: 140,
                      radius: 0,
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
                    _buildCoverPreview(
                      context,
                      previewCover,
                      width: 116,
                      height: 116,
                      radius: 16,
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
            child: Material(
              color: Colors.transparent,
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
                        builder: (context) =>
                            LockedDiaryPage(diaryId: diary.diary.diaryId),
                      ),
                    );
                    return;
                  }
                  onOpenEditor(diary.diary.diaryId);
                },
                onLongPress: () => onToggleSelection(diary.diary.diaryId, true),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    (compact || isLockedCapsule) ? 0 : 16,
                    (compact || isLockedCapsule) ? 0 : 14,
                    (compact || isLockedCapsule) ? 0 : 16,
                    (compact || isLockedCapsule) ? 0 : 14,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        );

        final animatedBaseItem = _buildAnimatedDiaryItem(
          diaryId: diary.diary.diaryId,
          child: item,
        );

        // 普通列表始终保留 Dismissible 根节点，避免进入选择模式时重建子树，
        // 从而让首次长按也能完整播放选中反馈；选择模式仅关闭滑动方向。
        if (!compact && onArchiveDiary != null) {
          final swipeBackgroundColor =
              swipeActionBackgroundColor ??
              Theme.of(context).colorScheme.primaryContainer;
          final swipeIconColor =
              swipeActionIconColor ??
              Theme.of(context).colorScheme.onPrimaryContainer;

          return Dismissible(
            key: ValueKey<String>('archive_${diary.diary.diaryId}'),
            direction: isSelectionMode
                ? DismissDirection.none
                : DismissDirection.endToStart,
            background: Container(
              color: swipeBackgroundColor,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSpacing.l),
              child: FaIcon(swipeActionIcon, size: 16, color: swipeIconColor),
            ),
            onDismissed: (_) => onArchiveDiary!(diary.diary.diaryId),
            child: animatedBaseItem,
          );
        }

        return animatedBaseItem;
      },
    );
  }

  Widget _buildAnimatedDiaryItem({
    required String diaryId,
    required Widget child,
  }) {
    final isExiting = pendingHideDiaryIds.contains(diaryId);
    final isAppearing = appearingDiaryIds.contains(diaryId);

    // 退出态切换为空组件，配合 AnimatedSwitcher 做“收起并淡出”。
    final switchedChild = isExiting
        ? SizedBox(key: ValueKey<String>('hidden_$diaryId'))
        : KeyedSubtree(key: ValueKey<String>('visible_$diaryId'), child: child);

    final switcher = AnimatedSwitcher(
      duration: _itemTransitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget transitionChild, Animation<double> animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? _) {
            // Flutter 的 SizeTransition 内部无条件包裹了 ClipRect(clipBehavior: Clip.hardEdge)。
            // 若在静止态（非折叠切换期）依然包裹 SizeTransition，ClipRect 会沿卡片外边界
            // 硬裁切，导致外散 BoxShadow 在卡片四角形成直角切边（直角阴影）。
            // 因此仅在动画未完成的过渡期间启用 SizeTransition，完成后直接返回子组件。
            if (animation.isCompleted) {
              return transitionChild;
            }
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: transitionChild,
              ),
            );
          },
        );
      },
      child: switchedChild,
    );

    // 非“新增出现态”时直接返回基础切换器。
    if (!isAppearing || isExiting) {
      return switcher;
    }

    // 出现态额外加一层高度与透明度补间，形成“从无到有”感。
    // 同理，补间完成（value >= 1.0）后移除 ClipRect，避免卡片阴影被矩形切边。
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('appear_$diaryId'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: _itemTransitionDuration,
      curve: Curves.easeOutCubic,
      child: switcher,
      builder: (BuildContext context, double value, Widget? animatedChild) {
        if (value >= 1.0) {
          return animatedChild!;
        }
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: value.clamp(0, 1),
            child: Opacity(opacity: value.clamp(0, 1), child: animatedChild),
          ),
        );
      },
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
    final contextMeta = _extractContextMetadata(diary.diary.metadata);
    final mood = contextMeta['moodEmoji']?.toString().trim();
    final weather = contextMeta['weather']?.toString().trim();
    final weatherIconCode = contextMeta['weatherIconCode']?.toString().trim();
    final energy = _parseEnergy(contextMeta['energyLevel']);
    final preview = diary.diary.contentText.replaceAll('\n', ' ').trim();
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
            EnergyBatteryIndicator.descriptionForValue(
              energy,
              isZh: context.l10n.isZh,
            ),
            leading: EnergyBatteryIndicator(value: energy, iconSize: 16),
          ),
      ],
    );

    final blurredBody = ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 12 : 14),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (previewCover != null)
                _buildCoverPreview(
                  context,
                  previewCover,
                  width: double.infinity,
                  height: compact ? 126 : 140,
                  radius: 0,
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: colorScheme.surfaceContainerHighest,
                child: Text(
                  preview.isEmpty ? title : preview,
                  maxLines: compact ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: ColoredBox(
                color: colorScheme.surface.withValues(alpha: 0.48),
              ),
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

  Map<String, Object?> _extractContextMetadata(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final context = decoded['context'];
        if (context is Map<String, dynamic>) {
          return context;
        }
      }
    } catch (_) {
      return const <String, Object?>{};
    }
    return const <String, Object?>{};
  }

  double? _parseEnergy(Object? raw) {
    final parsed = switch (raw) {
      num value => value.toDouble(),
      String value => double.tryParse(value),
      _ => null,
    };
    return parsed == null
        ? null
        : EnergyBatteryIndicator.normalizeValue(parsed);
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

  /// 封面解析优先级：
  /// 1) 日记显式封面字段；
  /// 2) 正文内容中第一张图片。
  String? _resolvePreviewCover(Diary diary) {
    final cacheKey =
        '${diary.diaryId}_${diary.updatedAt.microsecondsSinceEpoch}';
    if (_previewCoverCache.containsKey(cacheKey)) {
      return _previewCoverCache[cacheKey];
    }

    final explicitCover = diary.cover?.trim();
    final resolvedCover = (explicitCover != null && explicitCover.isNotEmpty)
        ? explicitCover
        : _extractFirstImageFromContent(diary.content);

    _cacheResolvedPreviewCover(cacheKey, resolvedCover);
    return resolvedCover;
  }

  /// 维护固定容量缓存，避免滚动期间重复解析正文 JSON。
  void _cacheResolvedPreviewCover(String key, String? cover) {
    if (_previewCoverCache.containsKey(key)) {
      return;
    }

    _previewCoverCache[key] = cover;
    _previewCoverCacheOrder.addLast(key);

    while (_previewCoverCacheOrder.length > _maxPreviewCoverCacheEntries) {
      final oldestKey = _previewCoverCacheOrder.removeFirst();
      _previewCoverCache.remove(oldestKey);
    }
  }

  /// 从 Quill Delta JSON 中提取第一张图片地址。
  String? _extractFirstImageFromContent(String contentJson) {
    final normalized = contentJson.trim();
    if (normalized.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(normalized);
      return _extractImageFromNode(decoded);
    } catch (_) {
      return null;
    }
  }

  /// 递归解析图片节点，兼容不同嵌套结构。
  String? _extractImageFromNode(Object? node) {
    if (node is List) {
      for (final item in node) {
        final image = _extractImageFromNode(item);
        if (image != null) {
          return image;
        }
      }
      return null;
    }

    if (node is! Map) {
      return null;
    }

    final insert = node['insert'];
    if (insert is Map) {
      final image = insert['image'];
      if (image is String && image.trim().isNotEmpty) {
        return image.trim();
      }
    }

    final type = node['type'];
    if (type == 'image') {
      final attributes = node['attributes'];
      if (attributes is Map) {
        final url = attributes['url'];
        if (url is String && url.trim().isNotEmpty) {
          return url.trim();
        }
      }
    }

    final root = node['root'];
    if (root != null) {
      final image = _extractImageFromNode(root);
      if (image != null) {
        return image;
      }
    }

    final children = node['children'];
    if (children != null) {
      final image = _extractImageFromNode(children);
      if (image != null) {
        return image;
      }
    }

    return null;
  }

  /// 构建封面预览图（自动区分网络图与本地图）。
  Widget _buildCoverPreview(
    BuildContext context,
    String imageSource, {
    double? width,
    required double height,
    required double radius,
  }) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = width != null && width.isFinite && width > 0
        ? (width * dpr).round()
        : null;
    // Supplying both dimensions makes ResizeImage decode to an exact rectangle
    // and distorts photos whose source aspect ratio differs from the card.
    // One bounded edge is enough; BoxFit.cover handles the crop at paint time.
    final cacheHeight = cacheWidth == null && height.isFinite && height > 0
        ? (height * dpr).round()
        : null;
    final trimmed = imageSource.trim();
    final uri = Uri.tryParse(trimmed);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    final imageWidget = isNetwork
        ? Image.network(
            trimmed,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: FilterQuality.low,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) =>
                    _buildCoverFallback(context),
          )
        : Image.file(
            File(trimmed),
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: FilterQuality.low,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) =>
                    _buildCoverFallback(context),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: imageWidget),
    );
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
