import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/diary_card_style/diary_card_style.dart';
import '../../viewmodels/diary_card_appearance.dart';
import '../../viewmodels/diary_card_date_formatter.dart';
import '../../viewmodels/diary_card_resolved_style.dart';
import '../../viewmodels/diary_card_view_data.dart';
import 'diary_card_badges.dart';

/// 卡片正文里两种有内部排版的行：眉线与底栏（`DiaryCardBlocks` 的一部分）。
///
/// 列表与瀑布流保留改版前各自的结构：列表眉线是“日期 + 徽章”整体占满、
/// 印章贴右；瀑布流眉线是日期占满、图钉贴右。默认样式下产出的部件树与
/// 改版前相同。
class DiaryCardLines {
  const DiaryCardLines({
    required this.diary,
    required this.viewData,
    required this.resolved,
    required this.appearance,
  });

  final DiaryWithTags diary;
  final DiaryCardViewData viewData;
  final DiaryCardResolvedStyle resolved;
  final DiaryCardAppearance appearance;

  /// 置顶徽章；未置顶或样式隐藏时为 null。
  Widget? pinBadge() {
    if (!diary.diary.isPinned) {
      return null;
    }
    final badge = resolved.style.content.pinnedBadge;
    if (badge == DiaryCardPinnedBadge.hidden) {
      return null;
    }
    return DiaryCardPinBadge(
      color: appearance.accentColor,
      compact: resolved.compact,
      showLabel: badge == DiaryCardPinnedBadge.standard && !resolved.compact,
      scale: resolved.metaScale,
    );
  }

  /// 眉线行（日期、置顶徽章、位于眉线的心情天气与选择标记）。
  Widget eyebrow(
    BuildContext context, {
    required DiaryCardMetaIndicators? indicators,
    required Widget? mark,
  }) {
    final style = resolved.style;
    final dateText = style.meta.showDate
        ? Text(
            DiaryCardDateFormatter.eyebrow(
              l10n: context.l10n,
              meta: style.meta,
              createdAt: diary.diary.createdAt,
              updatedAt: diary.diary.updatedAt,
              now: DateTime.now(),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolved.eyebrowStyle?.copyWith(
              color: appearance.eyebrowColor,
            ),
          )
        : null;
    final badge = pinBadge();
    final showIndicators = indicators != null && !indicators.isEmpty;

    if (resolved.compact) {
      // 瀑布流：日期占满一行，置顶图钉贴右。
      Widget row({Widget? trailing}) => Row(
        mainAxisAlignment: resolved.centered
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          if (resolved.centered)
            ?(dateText == null ? null : Flexible(child: dateText))
          else
            Expanded(child: dateText ?? const SizedBox.shrink()),
          if (trailing != null) ...[const SizedBox(width: 4), trailing],
          if (trailing == null && badge != null) ...[
            const SizedBox(width: 4),
            badge,
          ],
          ?mark,
        ],
      );
      if (!showIndicators) {
        return row();
      }
      // 心情天气放进窄列的眉线时，图钉 + 印章可能比整行还宽：整组按剩余
      // 宽度等比缩小（FittedBox 只缩不放），日期先让出空间，不会溢出。
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final reserved = 4 + (mark == null ? 0 : 26);
          return row(
            trailing: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth - reserved)
                    .clamp(0, double.infinity)
                    .toDouble(),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badge != null) ...[badge, const SizedBox(width: 4)],
                    indicators,
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // 列表：带封面时右侧文本列在 360dp 屏上只剩约 170dp，日期需可截断，
    // 否则与置顶徽章、天气心情印章同行时会溢出。外层 Expanded 占满剩余宽度
    // 让印章贴右；内层日期是唯一弹性子项，只在空间不足时才截断（不能用
    // Flexible + Spacer，二者会平分空间）。日期截到 0 仍放不下徽章时（320dp、
    // 大字号、英文“Pinned”），徽章再按剩余宽度收窄、文字省略——放得下时
    // 约束比徽章本身宽，排版与此前完全相同。
    Widget leadingRow(double maxWidth) {
      final gap = dateText != null ? 6.0 : 0.0;
      return Row(
        mainAxisSize: resolved.centered ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (dateText != null) Flexible(child: dateText),
          if (badge != null) ...[
            if (dateText != null) const SizedBox(width: 6),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth.isFinite
                    ? (maxWidth - gap).clamp(0, double.infinity).toDouble()
                    : double.infinity,
              ),
              child: badge,
            ),
          ],
        ],
      );
    }

    final leading = badge == null
        ? leadingRow(double.infinity)
        : LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                leadingRow(constraints.maxWidth),
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: resolved.centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (resolved.centered)
          Flexible(child: leading)
        else
          Expanded(child: leading),
        if (showIndicators) ...[const SizedBox(width: 6), indicators],
        ?mark,
      ],
    );
  }

  /// 底栏（时间、附加信息、位于底栏的心情天气）；没有任何内容时为 null。
  Widget? footer(
    BuildContext context, {
    required DiaryCardMetaIndicators? indicators,
  }) {
    final meta = resolved.style.meta;
    final timeLabel = DiaryCardDateFormatter.footer(
      l10n: context.l10n,
      mode: meta.footerTime,
      createdAt: diary.diary.createdAt,
      updatedAt: diary.diary.updatedAt,
      now: DateTime.now(),
    );
    final timeStyle = resolved.footerStyle?.copyWith(
      color: appearance.footerColor,
    );
    final extras = meta.hasFooterExtras
        ? buildDiaryCardFooterExtras(
            context,
            meta: meta,
            textStyle: resolved.footerStyle,
            color: appearance.footerColor,
            location: viewData.location,
            energyLevel: viewData.energyLevel,
            wordCount: viewData.wordCount,
            media: meta.showMedia ? viewData.media : null,
            scale: resolved.metaScale,
          )
        : const <Widget>[];
    final showIndicators = indicators != null && !indicators.isEmpty;
    if (timeLabel == null && extras.isEmpty && !showIndicators) {
      return null;
    }
    final timeText = timeLabel == null
        ? null
        : Text(
            timeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: resolved.centered ? TextAlign.center : null,
            style: timeStyle,
          );
    final Widget? leading = extras.isEmpty
        ? timeText
        : Wrap(
            spacing: 8 * resolved.metaScale,
            runSpacing: 2,
            alignment: resolved.centered
                ? WrapAlignment.center
                : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[?timeText, ...extras],
          );

    if (resolved.compact) {
      // 瀑布流：时间占满一行，心情天气印章贴右（改版前的结构）。
      return Row(
        children: [
          Expanded(child: leading ?? const SizedBox.shrink()),
          if (indicators != null) indicators,
        ],
      );
    }
    if (leading != null && !showIndicators && !resolved.centered) {
      return Row(children: [Flexible(child: leading)]);
    }
    return Row(
      mainAxisAlignment: resolved.centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (leading != null)
          resolved.centered
              ? Flexible(child: leading)
              : Expanded(child: leading)
        else if (!resolved.centered)
          const Spacer(),
        if (showIndicators) ...[
          if (leading != null) const SizedBox(width: 6),
          indicators,
        ],
      ],
    );
  }
}
