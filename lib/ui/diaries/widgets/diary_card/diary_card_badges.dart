import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../widgets/qweather_icon.dart';
import '../../models/diary_card_style/diary_card_style.dart';
import '../../viewmodels/diary_card_media_summary.dart';
import '../energy_battery_indicator.dart';

// 日记卡片上的小部件：置顶徽章、心情天气印章与底栏附加信息。尺寸乘以
// 辅助文字缩放 [scale]，为 1 时与改版前的写死值相同。

/// 置顶微徽章胶囊。
class DiaryCardPinBadge extends StatelessWidget {
  const DiaryCardPinBadge({
    super.key,
    required this.color,
    required this.compact,
    required this.showLabel,
    this.scale = 1,
  });

  final Color color;

  /// 瀑布流尺寸（更小的内边距与图标）。
  final bool compact;
  final bool showLabel;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (compact ? 5 : 6) * scale,
        vertical: (compact ? 1.5 : 2) * scale,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.65),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.thumbtack,
            size: (compact ? 8.5 : 9.5) * scale,
            color: color,
          ),
          if (showLabel) ...[
            SizedBox(width: 3.5 * scale),
            // 眉线极窄时徽章会被收窄：文字省略而不是溢出。
            Flexible(
              child: Text(
                context.l10n.diaryPinnedBadge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5 * scale,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 心情与天气指示器：[plain] 为 false 时是带底色的精致微胶囊印章，为 true
/// 时只画图标。两者都没有时不占位。
class DiaryCardMetaIndicators extends StatelessWidget {
  const DiaryCardMetaIndicators({
    super.key,
    required this.moodEmoji,
    required this.weatherCode,
    required this.compact,
    required this.fill,
    required this.border,
    required this.iconColor,
    this.plain = false,
    this.scale = 1,
  });

  final String? moodEmoji;
  final String? weatherCode;
  final bool compact;
  final Color fill;
  final Color border;

  /// 天气图标的颜色（SVG currentColor 与兜底图标共用）。
  final Color iconColor;
  final bool plain;
  final double scale;

  bool get isEmpty => moodEmoji == null && weatherCode == null;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return const SizedBox.shrink();
    }
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (weatherCode != null) ...[
          QWeatherIcon(
            iconCode: weatherCode,
            size: (compact ? 11.5 : 13) * scale,
            fallbackColor: iconColor,
          ),
          if (moodEmoji != null) SizedBox(width: (compact ? 3 : 4.5) * scale),
        ],
        if (moodEmoji != null)
          Text(
            moodEmoji!,
            style: TextStyle(
              fontSize: (compact ? 11 : 12.5) * scale,
              height: 1.1,
            ),
          ),
      ],
    );
    if (plain) {
      return row;
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (compact ? 5.5 : 7) * scale,
        vertical: (compact ? 1.5 : 2.5) * scale,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(color: border, width: 0.6),
      ),
      child: row,
    );
  }
}

/// 底栏的附加信息（地点、精力、字数、媒体）。返回的部件放进底栏的 Wrap，
/// 每项单行；地点过长时截断。
List<Widget> buildDiaryCardFooterExtras(
  BuildContext context, {
  required DiaryCardMetaStyle meta,
  required TextStyle? textStyle,
  required Color color,
  required String? location,
  required double? energyLevel,
  required int charCount,
  required DiaryCardMediaSummary? media,
  double scale = 1,
}) {
  final l10n = context.l10n;
  final iconSize = 10.5 * scale;
  final style = textStyle?.copyWith(color: color);
  Widget item(FaIconData icon, String? text, String semantics) {
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FaIcon(icon, size: iconSize, color: color),
          if (text != null) ...<Widget>[
            SizedBox(width: 3 * scale),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ],
      ),
    );
  }

  final items = <Widget>[];
  if (meta.showLocation && location != null) {
    items.add(
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 132 * scale),
        child: item(
          FontAwesomeIcons.locationDot,
          location,
          l10n.diaryCardLocation(location),
        ),
      ),
    );
  }
  if (meta.showEnergy && energyLevel != null) {
    final energy = EnergyBatteryIndicator.normalizeValue(energyLevel);
    items.add(
      Semantics(
        label: EnergyBatteryIndicator.descriptionForValue(energy, l10n),
        excludeSemantics: true,
        child: EnergyBatteryIndicator(value: energy, iconSize: 13 * scale),
      ),
    );
  }
  if (meta.showWordCount && charCount > 0) {
    final count = NumberFormat.decimalPattern(
      l10n.localeName,
    ).format(charCount);
    final text = l10n.diaryCardCharCount(count);
    items.add(item(FontAwesomeIcons.penNib, text, text));
  }
  if (meta.showMedia && media != null && !media.isEmpty) {
    if (media.imageCount > 0) {
      items.add(
        item(
          FontAwesomeIcons.image,
          '${media.imageCount}',
          l10n.diaryCardMediaImages(media.imageCount),
        ),
      );
    }
    if (media.audioCount > 0) {
      items.add(
        item(FontAwesomeIcons.microphone, null, l10n.diaryCardMediaAudio),
      );
    }
    if (media.videoCount > 0) {
      items.add(item(FontAwesomeIcons.video, null, l10n.diaryCardMediaVideo));
    }
    if (media.attachmentCount > 0) {
      items.add(
        item(FontAwesomeIcons.paperclip, null, l10n.diaryCardMediaAttachment),
      );
    }
  }
  return items;
}
