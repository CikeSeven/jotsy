import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/viewmodels/publish_panel_summary.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:node_diary/ui/widgets/qweather_icon.dart';

/// 面板收起时的摘要栏：已选的元数据一行概览。
///
/// 收起态不再只是一句“上划展开”：用户不展开也能看到这篇日记带着哪些
/// 标签、心情、地点。摘要排成一行富文本，空间不足时末尾省略；点按摘要
/// 展开面板由外层表头负责。
class PublishPanelSummaryBar extends StatelessWidget {
  const PublishPanelSummaryBar({
    super.key,
    required this.draft,
    required this.tags,
    this.notebooks = const <NotebookView>[],
    this.showCapsule = true,
  });

  /// 摘要区，测试与拖拽起点用它定位。
  static const Key summaryKey = ValueKey<String>('publish-panel-summary');

  final DiaryMetaDraftController draft;
  final List<Tag> tags;

  /// 书架上的日记本：把草稿里的日记本 id 解析成名称与图标。
  final List<NotebookView> notebooks;

  /// 是否显示草稿里的胶囊摘要项，见 `PublishDiaryPanel.showDraftCapsule`。
  final bool showCapsule;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DiaryMetaDraft>(
      valueListenable: draft,
      builder: (context, value, _) => KeyedSubtree(
        key: summaryKey,
        child: _SummaryLine(
          items: publishPanelSummary(
            value,
            tags,
            notebooks: notebooks,
            includeCapsule: showCapsule,
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.items});

  final List<PublishSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final mutedColor = colorScheme.onSurfaceVariant;
    if (items.isEmpty) {
      return Text(
        context.l10n.publishPanelSummaryEmpty,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseStyle?.copyWith(
          color: mutedColor,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    WidgetSpan icon(Widget child) =>
        WidgetSpan(alignment: PlaceholderAlignment.middle, child: child);
    final spans = <InlineSpan>[];
    for (final item in items) {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: '   '));
      switch (item) {
        case PublishSummaryCapsule():
          spans.add(
            icon(
              FaIcon(
                FontAwesomeIcons.lock,
                size: 12,
                color: colorScheme.primary,
              ),
            ),
          );
        case PublishSummaryMood(:final emoji):
          spans.add(TextSpan(text: emoji));
        case PublishSummaryWeather(:final iconCode, :final text):
          spans.add(
            icon(QWeatherIcon(iconCode: iconCode, weatherText: text, size: 14)),
          );
        case PublishSummaryTag(:final tag, :final more):
          spans
            ..add(
              TextSpan(
                text: '# ',
                style: TextStyle(
                  color: Color(tag.color),
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
            ..add(TextSpan(text: tag.name));
          if (more > 0) {
            spans.add(
              TextSpan(
                text: ' +$more',
                style: TextStyle(color: mutedColor),
              ),
            );
          }
        case PublishSummaryNotebook(:final notebook, :final more):
          spans
            ..add(icon(FaIcon(notebook.icon.data, size: 11, color: mutedColor)))
            ..add(TextSpan(text: ' ${notebook.name}'));
          if (more > 0) {
            spans.add(
              TextSpan(
                text: ' +$more',
                style: TextStyle(color: mutedColor),
              ),
            );
          }
        case PublishSummaryPlace(:final text):
          spans
            ..add(
              icon(
                FaIcon(
                  FontAwesomeIcons.locationDot,
                  size: 11,
                  color: mutedColor,
                ),
              ),
            )
            ..add(TextSpan(text: ' $text'));
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
    );
  }
}
