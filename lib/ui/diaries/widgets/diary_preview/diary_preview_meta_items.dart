import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../viewmodels/diary_preview_view_data.dart';
import 'diary_word_count_sheet.dart';

/// 信息栏里的一项：图标（或自定义前导，如天气图标）+ 单行文字。父级给出
/// 宽度上限时（[Wrap] 里）过长的文字省略，不会溢出。
class DiaryPreviewInlineMeta extends StatelessWidget {
  const DiaryPreviewInlineMeta({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    required this.color,
  }) : assert(icon != null || leading != null);

  final FaIconData? icon;
  final Widget? leading;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: color, height: 1);
    final iconSlotSize = textStyle?.fontSize ?? 14;
    final leadingWidget = leading ?? FaIcon(icon!, size: 12, color: color);

    // Row 的居中只能对齐组件布局盒，不能对齐图标和文字的可见轮廓：
    // FontAwesome 字形与天气 SVG 都会占满自己的方形盒，而正文文字底部仍受
    // 字体 ascent/descent 影响。这里把图标槽位收窄到正文字号，并轻微上移，
    // 让时钟、地址、天气图标按视觉中心与文案对齐。
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox.square(
          dimension: iconSlotSize,
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -1),
              child: leadingWidget,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );
  }
}

/// 信息栏里的字数：“1,234 字 · 约 4 分钟”（阅读时长可关），点按打开字数
/// 统计明细。
class DiaryPreviewWordCountMeta extends StatelessWidget {
  const DiaryPreviewWordCountMeta({
    super.key,
    required this.viewData,
    this.showReadingTime = true,
  });

  final DiaryPreviewViewData viewData;
  final bool showReadingTime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = viewData.textStats;
    final words = l10n.diaryPreviewWordCount(
      stats.words,
      NumberFormat.decimalPattern(l10n.localeName).format(stats.words),
    );
    final label = showReadingTime
        ? '$words · ${l10n.diaryPreviewReadingTime(stats.readingMinutes)}'
        : words;
    return Semantics(
      button: true,
      hint: l10n.diaryWordCountOpen,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => showDiaryWordCountSheet(
          context,
          stats: stats,
          media: viewData.media,
        ),
        child: DiaryPreviewInlineMeta(
          icon: FontAwesomeIcons.penNib,
          label: label,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 信息栏里的留言数：“2 条留言”，点按滚到正文末尾的留言区。
class DiaryPreviewCommentCountMeta extends StatelessWidget {
  const DiaryPreviewCommentCountMeta({
    super.key,
    required this.count,
    this.onTap,
  });

  final int count;

  /// 为 null 时不可点（设置页预览）。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = DiaryPreviewInlineMeta(
      icon: FontAwesomeIcons.comment,
      label: context.l10n.diaryCommentsCount(count),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final onTap = this.onTap;
    if (onTap == null) return meta;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: meta,
      ),
    );
  }
}
