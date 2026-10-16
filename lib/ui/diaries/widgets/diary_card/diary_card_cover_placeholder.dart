import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';

/// 没有封面时在封面位置显示的大号日期块：日 + 月份与星期。
///
/// 只取 primaryContainer 语义色，明暗主题都可读；内容经 FittedBox 缩放，
/// 小尺寸封面与大字号下不溢出。不参与共享元素（不是图片）。
class DiaryCardDateBlock extends StatelessWidget {
  const DiaryCardDateBlock({
    super.key,
    required this.date,
    required this.width,
    required this.height,
    required this.radius,
    this.horizontal = false,
  });

  final DateTime date;
  final double? width;
  final double height;
  final double radius;

  /// 横向排布（顶部通栏占位）：日在左，月份星期在右。
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.l10n.localeName;
    final local = date.toLocal();
    final day = Text(
      '${local.day}',
      style: textTheme.displaySmall?.copyWith(
        color: colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
    final caption = Text(
      '${DateFormat.MMM(locale).format(local)} · '
      '${DateFormat.E(locale).format(local)}',
      maxLines: 1,
      style: textTheme.labelMedium?.copyWith(
        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
        fontWeight: FontWeight.w600,
      ),
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: radius > 0 ? BorderRadius.circular(radius) : null,
      ),
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: horizontal
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[day, const SizedBox(width: 10), caption],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[day, const SizedBox(height: 4), caption],
              ),
      ),
    );
  }
}

/// 没有封面时显示当天心情的色块；没有心情时调用方不显示占位。
class DiaryCardMoodTile extends StatelessWidget {
  const DiaryCardMoodTile({
    super.key,
    required this.moodEmoji,
    required this.tint,
    required this.width,
    required this.height,
    required this.radius,
  });

  final String moodEmoji;

  /// 心情段颜色；样式未用心情色时为 null，退回中性的表面色。
  final Color? tint;
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fill = tint == null
        ? colorScheme.surfaceContainerHighest
        : Color.alphaBlend(
            tint!.withValues(alpha: 0.22),
            colorScheme.surfaceContainerLow,
          );
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius > 0 ? BorderRadius.circular(radius) : null,
      ),
      padding: const EdgeInsets.all(6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(moodEmoji, style: const TextStyle(fontSize: 40, height: 1)),
      ),
    );
  }
}
