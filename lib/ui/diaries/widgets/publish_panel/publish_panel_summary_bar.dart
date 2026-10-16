import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/viewmodels/publish_panel_summary.dart';
import 'package:node_diary/ui/widgets/qweather_icon.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

/// 面板收起时的摘要栏：已选的元数据一行概览 + （发布页）发表按钮。
///
/// 收起态不再只是一句“上划展开”：用户不展开也能看到这篇日记会带着哪些
/// 标签、心情、地点发出去，并直接发表。摘要排成一行富文本，空间不足时
/// 末尾省略；点按摘要展开面板由外层表头负责。
class PublishPanelSummaryBar extends StatelessWidget {
  const PublishPanelSummaryBar({
    super.key,
    required this.draft,
    required this.tags,
    required this.busy,
    required this.onPublish,
  });

  /// 摘要区（不含按钮），测试与拖拽起点用它定位。
  static const Key summaryKey = ValueKey<String>('publish-panel-summary');

  /// 收起栏上的发表按钮。
  static const Key actionKey = ValueKey<String>('publish-panel-summary-action');

  final DiaryMetaDraftController draft;
  final List<Tag> tags;
  final bool busy;

  /// 编辑已发布日记时为 null：只有摘要，没有按钮。
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    final onPublish = this.onPublish;
    return ValueListenableBuilder<DiaryMetaDraft>(
      valueListenable: draft,
      builder: (context, value, _) {
        final items = publishPanelSummary(value, tags);
        return Row(
          children: <Widget>[
            Expanded(
              child: KeyedSubtree(
                key: summaryKey,
                child: _SummaryLine(items: items),
              ),
            ),
            if (onPublish != null) ...<Widget>[
              const SizedBox(width: 8),
              ValueListenableSelector<DiaryMetaDraft, bool>(
                valueListenable: draft,
                selector: (value) => value.capsule != null,
                builder: (context, sealing, _) => FilledButton(
                  key: actionKey,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: busy ? null : onPublish,
                  child: Text(
                    sealing
                        ? context.l10n.publishPanelSealShort
                        : context.l10n.publishPanelPublishShort,
                  ),
                ),
              ),
            ],
          ],
        );
      },
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
