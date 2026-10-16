import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/text_stats.dart';
import '../../viewmodels/diary_card_media_summary.dart';

/// 打开一篇日记的字数统计明细（底部面板）。
Future<void> showDiaryWordCountSheet(
  BuildContext context, {
  required TextStats stats,
  required DiaryCardMediaSummary media,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext context) =>
        DiaryWordCountSheet(stats: stats, media: media),
  );
}

/// 字数统计明细：大号字数，其下是中文字符、非中文单词、字符数、段落、
/// 媒体数量（为 0 的媒体不列出）与预计阅读时长，最后是口径说明。数字使用
/// 等宽数字，上下行对齐。
class DiaryWordCountSheet extends StatelessWidget {
  const DiaryWordCountSheet({
    super.key,
    required this.stats,
    required this.media,
  });

  final TextStats stats;
  final DiaryCardMediaSummary media;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final number = NumberFormat.decimalPattern(l10n.localeName);
    const tabular = <FontFeature>[FontFeature.tabularFigures()];
    final rows = <(String, String)>[
      (l10n.diaryWordCountCjk, number.format(stats.cjk)),
      (l10n.diaryWordCountLatin, number.format(stats.latinWords)),
      (l10n.diaryWordCountCharacters, number.format(stats.characters)),
      (
        l10n.diaryWordCountCharactersWithSpaces,
        number.format(stats.charactersWithSpaces),
      ),
      (l10n.diaryWordCountParagraphs, number.format(stats.paragraphs)),
      if (media.imageCount > 0)
        (l10n.diaryWordCountImages, number.format(media.imageCount)),
      if (media.audioCount > 0)
        (l10n.diaryWordCountRecordings, number.format(media.audioCount)),
      if (media.videoCount > 0)
        (l10n.diaryWordCountVideos, number.format(media.videoCount)),
      if (media.attachmentCount > 0)
        (l10n.diaryWordCountAttachments, number.format(media.attachmentCount)),
      if (stats.readingMinutes > 0)
        (
          l10n.diaryWordCountReading,
          l10n.diaryPreviewReadingTime(stats.readingMinutes),
        ),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.diaryWordCountTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: number.format(stats.words),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      fontFeatures: tabular,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: l10n.diaryWordCountUnit(stats.words),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Column(
                  children: <Widget>[
                    for (final (label, value) in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              value,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontFeatures: tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.diaryWordCountRule,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
