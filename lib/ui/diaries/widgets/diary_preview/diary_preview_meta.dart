import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../notebooks/viewmodels/notebook_view.dart';
import '../../../notebooks/widgets/notebook_capsule.dart';
import '../../../widgets/qweather_icon.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import '../../viewmodels/diary_card_date_formatter.dart';
import '../../viewmodels/diary_preview_view_data.dart';
import '../energy_battery_indicator.dart';
import 'diary_preview_chips.dart';
import 'diary_preview_meta_items.dart';

export 'diary_preview_meta_items.dart';

/// 预览页信息栏：时间、字数、地点、天气与心情、精力、标签胶囊，以及这篇
/// 所在日记本的胶囊（排在标签之后、同一组，随“标签”开关显示，点按打开
/// 那本）。
///
/// 版式（[DiaryPreviewMetaStyle.layout]）：
/// - stacked：时间与字数一行、地点与天气一行、胶囊折行一组（改版前的样子）；
/// - inline：所有项目排成一段，按宽度自动折行；
/// - card：stacked 的内容收进一张圆角信息卡。
///
/// 每一项都可以单独关闭；没有数据的项（没填天气、没有标签……）不占位。所有
/// 行都用 [Wrap] 排布并限制单项宽度，过长的地名省略而不是横向滚动——页内
/// 不放横向滚动条，左右滑动始终留给翻页。
class DiaryPreviewMeta extends StatelessWidget {
  const DiaryPreviewMeta({
    super.key,
    required this.detail,
    required this.viewData,
    required this.style,
    this.notebooks = const <NotebookView>[],
    this.onOpenNotebook,
  });

  final DiaryWithTags detail;
  final DiaryPreviewViewData viewData;
  final DiaryPreviewMetaStyle style;

  /// 这篇所在的普通日记本（书架顺序）；设置页预览为空。
  final List<NotebookView> notebooks;

  /// 点按日记本胶囊；null 时胶囊不可点。
  final ValueChanged<NotebookView>? onOpenNotebook;

  /// 这一篇在当前样式下是否有任何信息可显示。
  static bool hasContent(
    DiaryWithTags detail,
    DiaryPreviewViewData viewData,
    DiaryPreviewMetaStyle style, {
    List<NotebookView> notebooks = const <NotebookView>[],
  }) {
    return style.showDate ||
        (style.showWordCount && viewData.textStats.words > 0) ||
        (style.showLocation && viewData.location != null) ||
        (style.showWeather && viewData.weather != null) ||
        (style.showMood && viewData.moodEmoji != null) ||
        (style.showEnergy && viewData.energyLevel != null) ||
        (style.showTags && (detail.tags.isNotEmpty || notebooks.isNotEmpty));
  }

  List<DiaryPreviewChipItem> _chipItems(AppLocalizations l10n) {
    final items = <DiaryPreviewChipItem>[];
    final mood = viewData.moodEmoji;
    if (style.showMood && mood != null) {
      items.add(
        DiaryPreviewChipItem(
          kind: DiaryPreviewChipKind.mood,
          label: '${l10n.autoT0116} $mood',
        ),
      );
    }
    final energy = viewData.energyLevel;
    if (style.showEnergy && energy != null) {
      final normalized = EnergyBatteryIndicator.normalizeValue(energy);
      items.add(
        DiaryPreviewChipItem(
          kind: DiaryPreviewChipKind.energy,
          label: EnergyBatteryIndicator.descriptionForValue(normalized, l10n),
          energyLevel: normalized,
        ),
      );
    }
    if (style.showTags) {
      for (final tag in detail.tags) {
        items.add(
          DiaryPreviewChipItem(
            kind: DiaryPreviewChipKind.tag,
            label: tag.name,
            tagColor: tag.color,
          ),
        );
      }
    }
    return items;
  }

  String _dateLabel(AppLocalizations l10n) {
    final created = style.dateSource == DiaryCardDateSource.created;
    final date = DiaryCardDateFormatter.format(
      l10n: l10n,
      format: style.dateFormat,
      showWeekday: style.showWeekday,
      showTime: style.showTime,
      date: created ? detail.diary.createdAt : detail.diary.updatedAt,
      now: DateTime.now(),
    );
    if (!style.datePrefix) {
      return date;
    }
    return '${created ? l10n.autoT0117 : l10n.diaryPreviewUpdatedPrefix} $date';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurfaceVariant;
    final timeItems = <Widget>[
      if (style.showDate)
        DiaryPreviewInlineMeta(
          icon: FontAwesomeIcons.clock,
          label: _dateLabel(l10n),
          color: muted,
        ),
      if (style.showWordCount && viewData.textStats.words > 0)
        DiaryPreviewWordCountMeta(
          viewData: viewData,
          showReadingTime: style.showReadingTime,
        ),
    ];
    final location = viewData.location;
    final weather = viewData.weather;
    final placeItems = <Widget>[
      if (style.showLocation && location != null)
        DiaryPreviewInlineMeta(
          icon: FontAwesomeIcons.locationDot,
          label: location,
          color: muted,
        ),
      if (style.showWeather && weather != null)
        DiaryPreviewInlineMeta(
          leading: QWeatherIcon(
            iconCode: viewData.weatherIconCode,
            weatherText: weather,
            size: 12,
          ),
          label: weather,
          color: muted,
        ),
    ];
    final chips = <Widget>[
      for (final item in _chipItems(l10n))
        DiaryPreviewChip(
          item: item,
          tagStyle: style.tagStyle,
          plain: style.chipStyle == DiaryPreviewChipStyle.plain,
        ),
      if (style.showTags)
        for (final notebook in notebooks)
          NotebookCapsule(
            key: ValueKey<String>('preview_notebook_${notebook.id}'),
            notebook: notebook,
            maxNameWidth: 200,
            onTap: onOpenNotebook == null
                ? null
                : () => onOpenNotebook!(notebook),
          ),
    ];

    if (style.layout == DiaryPreviewMetaLayout.inline) {
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[...timeItems, ...placeItems, ...chips],
      );
    }

    // 分行：时间行、地点天气行、胶囊组之间分别留 6 与 8（改版前的间距）。
    final rows = <(double, Widget)>[
      if (timeItems.length == 1)
        (0, timeItems.single)
      else if (timeItems.isNotEmpty)
        (0, _row(timeItems, spacing: 12, runSpacing: 6)),
      if (placeItems.isNotEmpty)
        (6, _row(placeItems, spacing: 12, runSpacing: 6)),
      // 胶囊高度略有不同（标签的 # 比文字大），沿用改版前的顶端对齐。
      if (chips.isNotEmpty)
        (8, Wrap(spacing: 8, runSpacing: 8, children: chips)),
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: rows[i].$1),
          rows[i].$2,
        ],
      ],
    );
    if (style.layout != DiaryPreviewMetaLayout.card) {
      return column;
    }
    final isLight = colorScheme.brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: isLight ? 0.45 : 0.6,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: isLight ? 0.4 : 0.3,
          ),
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(width: double.infinity, child: column),
      ),
    );
  }

  static Widget _row(
    List<Widget> children, {
    required double spacing,
    required double runSpacing,
  }) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
