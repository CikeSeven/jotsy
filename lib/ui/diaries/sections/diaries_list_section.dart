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
import 'diary_head_section.dart';

/// 日记页主列表区块。
///
/// 仅负责输出“日记内容本身”的 sliver，不再承载顶部标签条或独立滚动容器。
class DiariesListSection extends StatelessWidget {
  const DiariesListSection({
    super.key,
    required this.themeBrightness,
    required this.diaries,
    required this.layoutMode,
    required this.selectedDiaryIds,
    required this.isSelectionMode,
    required this.onCreate,
    required this.onOpenEditor,
    required this.onToggleSelection,
    this.onArchiveDiary,
  });

  final Brightness themeBrightness;
  final List<DiaryWithTags> diaries;
  final DiaryLayoutMode layoutMode;
  final Set<String> selectedDiaryIds;
  final bool isSelectionMode;
  final VoidCallback onCreate;
  final void Function(String diaryId) onOpenEditor;
  final void Function(String noteId, bool forceSelect) onToggleSelection;
  final ValueChanged<String>? onArchiveDiary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightMode = themeBrightness == Brightness.light;
    final backgroundColor = isLightMode ? Colors.white : colorScheme.surface;

    if (diaries.isEmpty) {
      return SliverToBoxAdapter(
        child: ColoredBox(
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.m,
            ),
            child: DiariesEmptyState(onCreate: onCreate),
          ),
        ),
      );
    }

    if (layoutMode == DiaryLayoutMode.waterfall) {
      return SliverPadding(
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.22),
                    ),
                  ),
              ],
            ),
          ),
        );
      }, childCount: diaries.length),
    );
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
    final title = diary.diary.title.trim().isEmpty ? '无标题' : diary.diary.title;
    final preview = diary.diary.contentText.replaceAll('\n', ' ').trim();

    return Builder(
      builder: (BuildContext _) {
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

        final compactTextContent = Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              compactHeader,
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 6),
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

        if (!compact && !isSelectionMode && onArchiveDiary != null) {
          return Dismissible(
            key: ValueKey<String>('archive_${diary.diary.diaryId}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSpacing.l),
              child: FaIcon(
                FontAwesomeIcons.boxArchive,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            onDismissed: (_) => onArchiveDiary!(diary.diary.diaryId),
            child: item,
          );
        }

        return item;
      },
    );
  }

  String? _resolvePreviewCover(Diary diary) {
    final explicitCover = diary.cover?.trim();
    if (explicitCover != null && explicitCover.isNotEmpty) {
      return explicitCover;
    }
    return _extractFirstImageFromContent(diary.content);
  }

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

  Widget _buildCoverFallback() {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(CupertinoIcons.photo, size: 20),
    );
  }
}
