import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/relative_time_formatter.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_surfaces.dart';

/// 笔记列表卡片组件。
///
/// 布局结构：
/// - 顶部：标题 + 选中态图标；
/// - 中部：正文预览（最多两行）；
/// - 底部：相对更新时间。
class DiaryCard extends StatelessWidget {
  const DiaryCard({
    super.key,
    required this.diary,
    required this.onTap,
    required this.onLongPress,
    required this.selected,
  });

  final DiaryWithTags diary;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final preview = diary.diary.contentText.replaceAll('\n', ' ');
    final isLight = colorScheme.brightness == Brightness.light;
    final itemBackgroundColor = selected
        ? colorScheme.secondaryContainer
        : ExpressiveSurfaces.cardColor(colorScheme);
    return Container(
      decoration: BoxDecoration(
        color: itemBackgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: selected
            ? Border.all(
                color: colorScheme.primary.withValues(alpha: 0.82),
                width: 1.5,
              )
            : Border.all(
                color: ExpressiveSurfaces.cardBorderColor(colorScheme),
                width: 0.8,
              ),
        boxShadow: isLight
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部眉线（日期）
                Row(
                  children: [
                    Text(
                      l10n.formatEyebrowDate(diary.diary.createdAt),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.82,
                        ),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.15,
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      FaIcon(
                        FontAwesomeIcons.solidCircleCheck,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // 标题行
                Text(
                  diary.diary.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // 正文摘要（无正文则不占位）。
                if (diary.diary.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.88,
                      ),
                      height: 1.42,
                    ),
                  ),
                  // 更新时间行。
                  const SizedBox(height: 10),
                ] else
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
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.72,
                        ),
                        fontSize: 11.5,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
