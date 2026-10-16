import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/relative_time_formatter.dart';
import '../../../widgets/qweather_icon.dart';
import '../../viewmodels/diary_preview_view_data.dart';
import '../energy_battery_indicator.dart';
import 'diary_preview_chips.dart';
import 'diary_word_count_sheet.dart';

/// 预览页信息栏：发表时间与字数一行，地点与天气一行，心情、精力与标签胶囊
/// 折行排列。
class DiaryPreviewMeta extends StatelessWidget {
  const DiaryPreviewMeta({
    super.key,
    required this.detail,
    required this.viewData,
  });

  final DiaryWithTags detail;
  final DiaryPreviewViewData viewData;

  List<DiaryPreviewChipItem> _chipItems(AppLocalizations l10n) {
    final items = <DiaryPreviewChipItem>[];
    final mood = viewData.moodEmoji;
    if (mood != null) {
      items.add(
        DiaryPreviewChipItem(
          kind: DiaryPreviewChipKind.mood,
          label: '${l10n.autoT0116} $mood',
        ),
      );
    }
    final energy = viewData.energyLevel;
    if (energy != null) {
      final normalized = EnergyBatteryIndicator.normalizeValue(energy);
      items.add(
        DiaryPreviewChipItem(
          kind: DiaryPreviewChipKind.energy,
          label: EnergyBatteryIndicator.descriptionForValue(normalized, l10n),
          energyLevel: normalized,
        ),
      );
    }
    for (final tag in detail.tags) {
      items.add(
        DiaryPreviewChipItem(
          kind: DiaryPreviewChipKind.tag,
          label: tag.name,
          tagColor: tag.color,
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final chips = _chipItems(l10n);
    final relativeCreated = RelativeTimeFormatter.formatUpdatedAt(
      updatedAt: detail.diary.createdAt,
      now: DateTime.now(),
      l10n: l10n,
    );
    final location = viewData.location;
    final weather = viewData.weather;
    final locationWeatherItems = <Widget>[
      if (location != null)
        DiaryPreviewInlineMeta(
          icon: FontAwesomeIcons.locationDot,
          label: location,
          color: colorScheme.onSurfaceVariant,
        ),
      if (weather != null)
        DiaryPreviewInlineMeta(
          leading: QWeatherIcon(
            iconCode: viewData.weatherIconCode,
            weatherText: weather,
            size: 12,
          ),
          label: weather,
          color: colorScheme.onSurfaceVariant,
        ),
    ];

    final timeItem = DiaryPreviewInlineMeta(
      icon: FontAwesomeIcons.clock,
      label: '${l10n.autoT0117} $relativeCreated',
      color: colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (viewData.textStats.words > 0)
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              timeItem,
              DiaryPreviewWordCountMeta(viewData: viewData),
            ],
          )
        else
          timeItem,
        if (locationWeatherItems.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (
                  int index = 0;
                  index < locationWeatherItems.length;
                  index++
                ) ...<Widget>[
                  if (index > 0) const SizedBox(width: 12),
                  locationWeatherItems[index],
                ],
              ],
            ),
          ),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map((item) => DiaryPreviewChip(item: item))
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

/// 信息栏里的一项：图标（或自定义前导，如天气图标）+ 单行文字。
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
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
      ],
    );
  }
}

/// 信息栏里的字数：“1,234 字 · 约 4 分钟”，点按打开字数统计明细。
class DiaryPreviewWordCountMeta extends StatelessWidget {
  const DiaryPreviewWordCountMeta({super.key, required this.viewData});

  final DiaryPreviewViewData viewData;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = viewData.textStats;
    final words = l10n.diaryPreviewWordCount(
      stats.words,
      NumberFormat.decimalPattern(l10n.localeName).format(stats.words),
    );
    final label =
        '$words · ${l10n.diaryPreviewReadingTime(stats.readingMinutes)}';
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
