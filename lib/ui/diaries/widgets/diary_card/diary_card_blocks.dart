import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../models/diary_card_style/diary_card_style.dart';
import '../../viewmodels/diary_card_appearance.dart';
import '../../viewmodels/diary_card_resolved_style.dart';
import '../../viewmodels/diary_card_view_data.dart';
import '../diary_item_tag_row.dart';
import 'diary_card_badges.dart';
import 'diary_card_lines.dart';
import 'diary_card_selection_mark.dart';

/// 卡片正文：按样式中的区块顺序排出眉线、标题、标签、摘要与底栏。
///
/// 输入为已解析的样式与颜色；不持有状态。区块之间用 `elementGap` 分隔，
/// 底栏前用略大的 `footerGap`；没有内容的区块（隐藏、没有标签或摘要为空）
/// 连同它前面的间距一起省略。默认样式下产出的部件结构与改版前逐项相同。
///
/// 选择标记挂在标题行末尾；这篇不显示标题行时（样式隐藏标题，或没写标题
/// 且关闭了“无标题”占位）挂到眉线行，两者都没有时由卡片以浮层显示（见
/// [selectionMarkHost]）。
class DiaryCardBlocks extends StatelessWidget {
  const DiaryCardBlocks({
    super.key,
    required this.diary,
    required this.viewData,
    required this.title,
    required this.resolved,
    required this.appearance,
    required this.selected,
    required this.isSelectionMode,
    required this.maxVisibleTags,
    required this.metaPosition,
    required this.selectionMarkDuration,
    this.commentCount = 0,
  });

  final DiaryWithTags diary;
  final DiaryCardViewData viewData;

  /// 标题行文字；null 表示这篇不显示标题行（见 [titleLine]）。
  final String? title;
  final DiaryCardResolvedStyle resolved;
  final DiaryCardAppearance appearance;
  final bool selected;
  final bool isSelectionMode;
  final int maxVisibleTags;

  /// 心情天气实际所在位置（封面上时这里不画）。
  final DiaryCardMetaPosition metaPosition;
  final Duration selectionMarkDuration;

  /// 这篇的留言条数（底栏的留言数；留言功能关闭时为 0）。
  final int commentCount;

  /// 标题行要显示的文字：样式隐藏标题时为 null；日记没写标题时按
  /// “无标题”占位开关取 [untitled] 或 null（不显示标题行）。
  static String? titleLine(
    DiaryCardContentStyle content, {
    required String title,
    required String untitled,
  }) {
    if (!content.showTitle) {
      return null;
    }
    if (title.trim().isNotEmpty) {
      return title;
    }
    return content.showUntitled ? untitled : null;
  }

  /// 选择标记所在的区块；null 表示标题行与眉线都不显示，由卡片以浮层显示。
  static DiaryCardBlock? selectionMarkHost({
    required bool hasTitle,
    required bool hasEyebrow,
  }) {
    if (hasTitle) {
      return DiaryCardBlock.title;
    }
    return hasEyebrow ? DiaryCardBlock.eyebrow : null;
  }

  /// 眉线是否有内容（日期、置顶徽章或位于眉线的心情天气）。
  static bool hasEyebrowContent({
    required DiaryCardStyle style,
    required bool pinned,
    required bool hasIndicators,
    required DiaryCardMetaPosition metaPosition,
  }) {
    return style.meta.showDate ||
        (pinned && style.content.pinnedBadge != DiaryCardPinnedBadge.hidden) ||
        (hasIndicators && metaPosition == DiaryCardMetaPosition.eyebrow);
  }

  @override
  Widget build(BuildContext context) {
    final style = resolved.style;
    final compact = resolved.compact;
    final pinned = diary.diary.isPinned;
    final indicators = buildIndicators();
    final hasIndicators = !indicators.isEmpty;
    final hasEyebrow = hasEyebrowContent(
      style: style,
      pinned: pinned,
      hasIndicators: hasIndicators,
      metaPosition: metaPosition,
    );
    final title = this.title;
    final markHost = selectionMarkHost(
      hasTitle: title != null,
      hasEyebrow: hasEyebrow,
    );
    final lines = DiaryCardLines(
      diary: diary,
      viewData: viewData,
      resolved: resolved,
      appearance: appearance,
      commentCount: commentCount,
    );
    final mark = DiaryCardSelectionMark(
      selected: selected,
      isSelectionMode: isSelectionMode,
      compact: compact,
      selectedColor: appearance.accentColor,
      unselectedColor: appearance.mutedColor,
      duration: selectionMarkDuration,
    );

    final children = <Widget>[];
    for (final block in style.content.blocks) {
      final Widget? built = switch (block) {
        DiaryCardBlock.eyebrow =>
          hasEyebrow
              ? lines.eyebrow(
                  context,
                  indicators: metaPosition == DiaryCardMetaPosition.eyebrow
                      ? indicators
                      : null,
                  mark: markHost == DiaryCardBlock.eyebrow ? mark : null,
                )
              : null,
        DiaryCardBlock.title => title == null ? null : _title(title, mark),
        DiaryCardBlock.tags => _tags(),
        DiaryCardBlock.preview => _preview(),
        DiaryCardBlock.footer => lines.footer(
          context,
          indicators: metaPosition == DiaryCardMetaPosition.footer
              ? indicators
              : null,
        ),
      };
      if (built == null) {
        continue;
      }
      if (children.isNotEmpty) {
        children.add(
          SizedBox(
            height: block == DiaryCardBlock.footer
                ? resolved.footerGap
                : resolved.modeStyle.elementGap,
          ),
        );
      }
      children.add(built);
    }
    return Column(
      crossAxisAlignment: resolved.centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 心情天气指示器（按样式开关过滤；位置由调用方决定）。
  DiaryCardMetaIndicators buildIndicators({bool onCover = false}) {
    final meta = resolved.style.meta;
    return DiaryCardMetaIndicators(
      moodEmoji: meta.showMood ? viewData.moodEmoji : null,
      weatherCode: meta.showWeather ? viewData.weatherIconCode : null,
      compact: resolved.compact,
      plain: meta.indicatorStyle == DiaryCardIndicatorStyle.plain,
      fill: onCover
          ? resolved.colorScheme.surface.withValues(alpha: 0.82)
          : appearance.chipFill,
      border: onCover
          ? resolved.colorScheme.outlineVariant.withValues(alpha: 0.4)
          : appearance.chipBorder,
      iconColor: onCover
          ? resolved.colorScheme.onSurfaceVariant
          : appearance.bodyColor,
      scale: resolved.metaScale,
    );
  }

  Widget _title(String title, Widget mark) {
    final m = resolved.modeStyle;
    return Row(
      crossAxisAlignment: resolved.compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: m.titleMaxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: resolved.centered ? TextAlign.center : null,
            style: resolved.titleStyle?.copyWith(color: appearance.titleColor),
          ),
        ),
        mark,
      ],
    );
  }

  Widget? _tags() {
    if (diary.tags.isEmpty || maxVisibleTags <= 0) {
      return null;
    }
    final inverted = appearance.inverted;
    return DiaryItemTagRow(
      tags: diary.tags,
      maxVisibleTags: maxVisibleTags,
      style: resolved.style.content.tagStyle,
      scale: resolved.metaScale,
      alignment: resolved.centered ? WrapAlignment.center : WrapAlignment.start,
      textColor: appearance.bodyColor,
      overflowFill: inverted ? appearance.chipFill : null,
      overflowBorder: inverted ? appearance.chipBorder : null,
    );
  }

  Widget? _preview() {
    final preview = viewData.previewText;
    if (!resolved.style.content.showPreview || preview.isEmpty) {
      return null;
    }
    return Text(
      preview,
      maxLines: resolved.modeStyle.previewMaxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: resolved.centered ? TextAlign.center : null,
      style: resolved.previewStyle?.copyWith(color: appearance.previewColor),
    );
  }
}
