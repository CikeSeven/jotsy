import 'package:flutter/material.dart';

import '../viewmodels/calendar_lunar_day.dart';

/// 日期格内部排版：数字居中，指示物贴底；角标挂在数字两侧而不是格子角上。
///
/// 圆点/心情/标签色样式的格子没有可见边框，角标若放在格子四角，会落在
/// 两个日期数字之间，看不出属于哪一天；紧贴数字左上、右上（各留 1.5dp
/// 间隙，不与数字重叠）归属才明确，也不遮挡日期。角标以固定宽度的槽位
/// 挂在数字框外侧，不改变数字的居中位置。
///
/// 显示农历时排成三层：数字、农历小字（[subtitle]）、底部指示物。数字与
/// 小字作为一组，在扣掉底部 [bottomReserve] 后的区域内居中，指示物仍贴底；
/// 同一网格里的格子用同样的预留高度，有无日记的日子数字都在同一水平线上。
/// 这一组按格子宽度排版，过宽的小字只缩小自己；系统大字号下整组超出
/// 高度时再整体等比缩小，而不是溢出。
class CalendarCellLayout extends StatelessWidget {
  const CalendarCellLayout({
    super.key,
    required this.number,
    this.indicator,
    this.leadingBadge,
    this.trailingBadge,
    this.subtitle,
    this.bottomReserve = 0,
  });

  /// 角标槽位宽度：放得下“9+”上标与带底的照片角标（13dp）。
  static const double _slot = 13;
  static const double _gap = 1.5;

  /// 三层排版时为底部指示物预留的高度：最高的指示物是心情 emoji（10dp），
  /// 贴底 3dp，与上方小字再留 1dp。
  static const double indicatorBand = 14;

  final Widget number;
  final Widget? indicator;

  /// 数字左上方：未解封胶囊的锁或天气。
  final Widget? leadingBadge;

  /// 数字右上方：篇数上标。
  final Widget? trailingBadge;

  /// 数字下方的农历小字。
  final Widget? subtitle;

  /// 数字组居中时扣掉的底部高度；为 0 且没有 [subtitle] 时数字在整格居中
  /// （不显示农历时的原有排版）。
  final double bottomReserve;

  @override
  Widget build(BuildContext context) {
    final head = _buildHead();
    final subtitle = this.subtitle;
    final indicator = this.indicator;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: <Widget>[
        if (subtitle == null && bottomReserve == 0)
          Center(child: head)
        else
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: bottomReserve,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // 宽度固定为格子宽度，小字的 FittedBox 才拿得到宽度上限；
                // 外层 FittedBox 只在整组高过可用区域时生效。
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        head,
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 1),
                          subtitle,
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (indicator != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 3,
            child: Center(child: indicator),
          ),
      ],
    );
  }

  Widget _buildHead() {
    final leadingBadge = this.leadingBadge;
    final trailingBadge = this.trailingBadge;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        number,
        if (leadingBadge != null)
          Positioned(
            top: -5,
            left: -(_slot + _gap),
            width: _slot,
            child: Align(alignment: Alignment.topRight, child: leadingBadge),
          ),
        if (trailingBadge != null)
          Positioned(
            top: -2,
            right: -(_slot + _gap),
            width: _slot,
            child: Align(alignment: Alignment.topLeft, child: trailingBadge),
          ),
      ],
    );
  }
}

/// 日期数字下方的农历小字：节日、节气或农历日。
///
/// 只占一行；窄屏加周数列时格子内容宽度只有约 25dp，“国庆节”“闰六月”
/// 这类三个字的词按宽度等比缩小，不换行、不截断。节日与节气加粗，与
/// 普通农历日拉开层次。
class CalendarCellLunarLabel extends StatelessWidget {
  const CalendarCellLunarLabel({
    super.key,
    required this.text,
    required this.color,
    this.emphasized = false,
  });

  final String text;
  final Color color;
  final bool emphasized;

  /// 普通格子上按类别取色：节日 tertiary、节气 primary、其余弱化；选中、
  /// 今天、热力等有填充色的格子统一用该格前景色 [onFill]（彩色小字放在
  /// primary/tertiary 底上会撞色），相邻月份的日期与数字一起淡化。
  static Color colorFor(
    ColorScheme colorScheme,
    CalendarLunarKind kind, {
    Color? onFill,
    bool isOutside = false,
  }) {
    final emphasized = isEmphasized(kind);
    if (onFill != null) {
      return emphasized ? onFill : onFill.withValues(alpha: 0.8);
    }
    if (isOutside) {
      return colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    }
    return switch (kind) {
      CalendarLunarKind.festival => colorScheme.tertiary,
      CalendarLunarKind.term => colorScheme.primary,
      CalendarLunarKind.monthStart ||
      CalendarLunarKind.day => colorScheme.onSurfaceVariant,
    };
  }

  static bool isEmphasized(CalendarLunarKind kind) =>
      kind == CalendarLunarKind.festival || kind == CalendarLunarKind.term;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 9,
          height: 1.15,
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
          color: color,
        ),
      ),
    );
  }
}
