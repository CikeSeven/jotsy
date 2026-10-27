import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import 'calendar_cell_layout.dart';
import 'day_mood_face.dart';

/// 记了心情的日期格内容：整格铺上心情的底色，日期数字缩小放到顶部，下面
/// 是一张占满余下空间的脸——整个格子就是这天的表情。
///
/// 输入：日期数字、心情与配色（相邻月份由调用方传入淡化后的配色）、数字
/// 两侧的角标与农历小字；输出整块内容，高亮（选中 / 今天 / 范围）由外层
/// [CalendarDayCell] 以描边画在外圈。无副作用。
///
/// 排版：数字组（数字 + 角标 + 农历小字）贴顶，最多占格子高度的一半，系统
/// 大字号下整组等比缩小而不是挤掉脸；脸取余下区域里最大的正方形居中。格子
/// 有可见的底色，数字缩到顶部仍一眼看得出属于哪一格。
class CalendarMoodTile extends StatelessWidget {
  const CalendarMoodTile({
    super.key,
    required this.day,
    required this.mood,
    required this.colors,
    required this.borderRadius,
    this.leadingBadge,
    this.trailingBadge,
    this.subtitle,
  });

  final int day;
  final DayMood mood;
  final DayMoodColors colors;
  final BorderRadius borderRadius;

  /// 数字左上方：锁 / 休班 / 纪念日心形 / 天气，见 CalendarCellLeadingBadge。
  final Widget? leadingBadge;

  /// 数字右上方：篇数上标，或写了一篇时的小圆点（见 [writtenDot]）。
  final Widget? trailingBadge;

  /// 数字下方的农历小字或纪念日名称；不显示农历时为 null。
  final Widget? subtitle;

  /// 这天写了日记、但篇数上标不显示时的记号：心情格的底部是脸，放不下
  /// 普通格的圆点指示物，改为数字右上方一个小圆点，仍看得出这天写过。
  static Widget writtenDot(Color color) => Padding(
    padding: const EdgeInsets.only(top: 1),
    child: Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Semantics(
      label: dayMoodLabel(context.l10n, mood),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.tile,
          borderRadius: borderRadius,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            // 宽窗口的格子更大，数字跟着放大一点（手机 ~11、宽窗口到 13）。
            final numberSize = (height * 0.27).clamp(10.5, 13.0);
            final number = Text(
              '$day',
              style: TextStyle(
                fontSize: numberSize,
                height: 1,
                fontWeight: FontWeight.w700,
                color: colors.onTile,
              ),
            );
            return Column(
              children: <Widget>[
                SizedBox(height: height * 0.07),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height * 0.5),
                  // 宽度固定为格子宽：农历小字的 FittedBox 拿得到宽度上限，
                  // 过长只缩小自己；外层只在整组超高时整体缩小。
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: width,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          CalendarCellLayout.buildHead(
                            number: number,
                            leadingBadge: leadingBadge,
                            trailingBadge: trailingBadge,
                          ),
                          if (subtitle != null) ...<Widget>[
                            const SizedBox(height: 1),
                            subtitle,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      width * 0.1,
                      height * 0.03,
                      width * 0.1,
                      height * 0.08,
                    ),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: DayMoodFace(mood: mood, color: colors.onTile),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
