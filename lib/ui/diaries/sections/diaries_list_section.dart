import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/relative_time_formatter.dart';
import '../widgets/diaries_empty_state.dart';
import '../widgets/diary_item_tag_row.dart';
import 'diary_head_section.dart';

/// 日记页主列表区块。
///
/// 仅负责输出“日记内容本身”的 sliver，不再承载顶部标签条或独立滚动容器。
class DiariesListSection extends StatelessWidget {
  /// 单条日记项进入/退出列表时的过渡时长。
  static const Duration _itemTransitionDuration = Duration(milliseconds: 220);

  const DiariesListSection({
    super.key,
    required this.themeBrightness,
    required this.diaries,
    required this.layoutMode,
    required this.selectedDiaryIds,
    required this.isSelectionMode,
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

  /// 当前主题亮暗，用于选择背景基色。
  final Brightness themeBrightness;
  /// 视图层已过滤/排序后的日记数据。
  final List<DiaryWithTags> diaries;
  /// 列表布局模式：列表 or 瀑布流。
  final DiaryLayoutMode layoutMode;
  /// 当前被选中的日记 ID 集合。
  final Set<String> selectedDiaryIds;
  final bool isSelectionMode;
  /// 标记“正在收起隐藏”的日记项集合。
  final Set<String> pendingHideDiaryIds;
  /// 标记“正在出现动画”的日记项集合。
  final Set<String> appearingDiaryIds;
  final VoidCallback onCreate;
  final void Function(String diaryId) onOpenEditor;
  final void Function(String noteId, bool forceSelect) onToggleSelection;
  final ValueChanged<String>? onArchiveDiary;
  final IconData swipeActionIcon;
  final Color? swipeActionBackgroundColor;
  final Color? swipeActionIconColor;
  /// 空列表时是否处于“搜索结果为空”语义。
  final bool isSearchResultEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightMode = themeBrightness == Brightness.light;
    final backgroundColor = isLightMode ? Colors.white : colorScheme.surface;
    final waterfallLayoutSignature = _buildWaterfallLayoutSignature(diaries);

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
              child: _buildDiaryItem(
                context,
                diary: diary,
                compact: true,
                backgroundColor: backgroundColor,
              ),
            );
          },
        ),
      );
    }

    // 普通列表模式：单列行列表，使用分割线分隔条目。
    return SliverList(
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        final diary = diaries[index];
        final isLast = index == diaries.length - 1;
        return KeyedSubtree(
          key: ValueKey<String>('list_${diary.diary.diaryId}'),
          child: ColoredBox(
            color: backgroundColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildDiaryItem(
                  context,
                  diary: diary,
                  compact: false,
                  backgroundColor: backgroundColor,
                ),
                if (!isLast)
                  Container(
                    height: 3,
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surface,
                  ),
              ],
            ),
          ),
        );
      }, childCount: diaries.length),
    );
  }

  /// 根据当前瀑布流数据顺序生成稳定签名。
  /// 当条目排序变化（如编辑后更新时间变化）时，触发瀑布流 sliver 重建，避免旧布局残留空位。
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
    required Color backgroundColor,
  }) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final itemBackgroundColor =
        compact ? colorScheme.surface : backgroundColor;
    final selected = selectedDiaryIds.contains(diary.diary.diaryId);
    final previewCover = _resolvePreviewCover(diary.diary);
    final title = diary.diary.title.trim().isEmpty
        ? l10n.autoT0033
        : diary.diary.title;
    final preview = diary.diary.contentText.replaceAll('\n', ' ').trim();
    final hasTags = diary.tags.isNotEmpty;

    return Builder(
      builder: (BuildContext _) {
        // 列表模式正文区域（标题/标签/摘要/时间）结构。
        final detailContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasTags) ...[
              const SizedBox(height: 6),
              DiaryItemTagRow(tags: diary.tags),
            ],
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                preview,
                maxLines: compact ? 4 : 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              RelativeTimeFormatter.formatUpdatedAt(
                updatedAt: diary.diary.updatedAt,
                now: DateTime.now(),
                l10n: l10n,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

        // 瀑布流模式标题行，选中态在右侧显示勾选图标。
        final compactHeader = Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: 18,
                color: colorScheme.primary,
              ),
          ],
        );

        // 瀑布流文本区域（位于可选封面下方）。
        final compactTextContent = Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              compactHeader,
              if (hasTags) ...[
                DiaryItemTagRow(tags: diary.tags),
              ],
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                RelativeTimeFormatter.formatUpdatedAt(
                  updatedAt: diary.diary.updatedAt,
                  now: DateTime.now(),
                  l10n: l10n,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );

        // 两种布局模式使用不同内容骨架，交互逻辑保持一致。
        final content =
            compact
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (previewCover != null)
                      _buildCoverPreview(
                        previewCover,
                        width: double.infinity,
                        height: 132,
                        radius: 0,
                      ),
                    compactTextContent,
                  ],
                )
                : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (previewCover != null) ...[
                      _buildCoverPreview(
                        previewCover,
                        width: 84,
                        height: 84,
                        radius: 10,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: detailContent),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ],
                  ],
                );

        final itemRadius = compact ? 14.0 : 0.0;

        // 统一点击交互：
        // - 选择模式下点击切换选中；
        // - 普通模式下点击进入详情（当前为预览页）；
        // - 长按强制选中。
        final item = ClipRRect(
          borderRadius: BorderRadius.circular(itemRadius),
          child: Material(
            color: itemBackgroundColor,
            child: InkWell(
              borderRadius:
                  itemRadius > 0 ? BorderRadius.circular(itemRadius) : null,
              onTap: () {
                if (isSelectionMode) {
                  onToggleSelection(diary.diary.diaryId, false);
                  return;
                }
                onOpenEditor(diary.diary.diaryId);
              },
              onLongPress: () => onToggleSelection(diary.diary.diaryId, true),
              child: Container(
                decoration:
                    compact
                        ? BoxDecoration(
                          color: itemBackgroundColor,
                          borderRadius: BorderRadius.circular(itemRadius),
                        )
                        : BoxDecoration(color: itemBackgroundColor),
                padding: EdgeInsets.fromLTRB(
                  compact ? 0 : 16,
                  compact ? 0 : 12,
                  compact ? 0 : 16,
                  compact ? 0 : 12,
                ),
                child: content,
              ),
            ),
          ),
        );

        final animatedBaseItem = _buildAnimatedDiaryItem(
          diaryId: diary.diary.diaryId,
          child: item,
        );

        // 仅普通列表启用左滑归档，瀑布流不启用侧滑动作。
        if (!compact && !isSelectionMode && onArchiveDiary != null) {
          final swipeBackgroundColor =
              swipeActionBackgroundColor ??
              Theme.of(context).colorScheme.primaryContainer;
          final swipeIconColor =
              swipeActionIconColor ??
              Theme.of(context).colorScheme.onPrimaryContainer;

          return Dismissible(
            key: ValueKey<String>('archive_${diary.diary.diaryId}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: swipeBackgroundColor,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSpacing.l),
              child: FaIcon(
                swipeActionIcon,
                size: 16,
                color: swipeIconColor,
              ),
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
    final switchedChild =
        isExiting
            ? SizedBox(key: ValueKey<String>('hidden_$diaryId'))
            : KeyedSubtree(
              key: ValueKey<String>('visible_$diaryId'),
              child: child,
            );

    final switcher = AnimatedSwitcher(
      duration: _itemTransitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget transitionChild, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: transitionChild,
          ),
        );
      },
      child: switchedChild,
    );

    // 非“新增出现态”时直接返回基础切换器。
    if (!isAppearing || isExiting) {
      return switcher;
    }

    // 出现态额外加一层高度与透明度补间，形成“从无到有”感。
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('appear_$diaryId'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: _itemTransitionDuration,
      curve: Curves.easeOutCubic,
      child: switcher,
      builder: (BuildContext context, double value, Widget? animatedChild) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: value.clamp(0, 1),
            child: Opacity(
              opacity: value.clamp(0, 1),
              child: animatedChild,
            ),
          ),
        );
      },
    );
  }

  /// 封面解析优先级：
  /// 1) 日记显式封面字段；
  /// 2) 正文内容中第一张图片。
  String? _resolvePreviewCover(Diary diary) {
    final explicitCover = diary.cover?.trim();
    if (explicitCover != null && explicitCover.isNotEmpty) {
      return explicitCover;
    }
    return _extractFirstImageFromContent(diary.content);
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
    String imageSource, {
    double? width,
    required double height,
    required double radius,
  }) {
    final trimmed = imageSource.trim();
    final uri = Uri.tryParse(trimmed);
    final isNetwork = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    final imageWidget =
        isNetwork
            ? Image.network(
              trimmed,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) =>
                      _buildCoverFallback(),
            )
            : Image.file(
              File(trimmed),
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) =>
                      _buildCoverFallback(),
            );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: imageWidget,
      ),
    );
  }

  /// 封面加载失败占位图。
  Widget _buildCoverFallback() {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(CupertinoIcons.photo, size: 20),
    );
  }
}
