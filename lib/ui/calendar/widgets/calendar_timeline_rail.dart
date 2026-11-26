import 'package:flutter/material.dart';

/// 时间线上的一项：右侧内容 [child]，左侧竖线在距这一项顶端 [anchor] 处
/// 穿过节点 [node]（null 时线直接经过，如待办行、分组标题）。[id] 在同一条
/// 时间线里唯一，用作这一项与它那段竖线的键。
@immutable
class CalendarRailEntry {
  const CalendarRailEntry({
    required this.id,
    required this.child,
    this.node,
    this.anchor = CalendarTimelineRail.defaultAnchor,
  });

  final String id;
  final Widget child;
  final Widget? node;
  final double anchor;
}

/// 选中日时间线的“左线右文”骨架：只负责竖线与节点的摆放，内容由调用方
/// 给出（日记卡片、待办行、添加入口）。
///
/// 竖线按每一项的实际高度铺满（#370）：项与项之间的间距收在项内，线从上一
/// 项接到下一项；第一项从它的锚点往下、最后一项画到它的锚点为止，只有一项
/// 时不画线。节点盖在线上，居中在锚点。
class CalendarTimelineRail extends StatelessWidget {
  const CalendarTimelineRail({super.key, required this.entries});

  final List<CalendarRailEntry> entries;

  /// 左侧竖线列宽与线宽；项与项之间的间距。
  static const double railWidth = 34;
  static const double lineWidth = 1.5;
  static const double itemGap = 8;

  /// 默认锚点：日记卡片的节点中心（距卡片顶 28）。
  static const double defaultAnchor = 28;

  /// 每一项那段竖线的键为此前缀 + [CalendarRailEntry.id]（测试据此量线段
  /// 是否首尾相接）。
  @visibleForTesting
  static const String lineKeyPrefix = 'calendar_timeline_rail_';

  @override
  Widget build(BuildContext context) {
    final lineColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < entries.length; index++)
          _buildEntry(
            entries[index],
            isFirst: index == 0,
            isLast: index == entries.length - 1,
            lineColor: lineColor,
          ),
      ],
    );
  }

  Widget _buildEntry(
    CalendarRailEntry entry, {
    required bool isFirst,
    required bool isLast,
    required Color lineColor,
  }) {
    final node = entry.node;
    return KeyedSubtree(
      key: ValueKey<String>('calendar_rail_entry_${entry.id}'),
      child: Stack(
        // 卡片带外阴影，不裁切。
        clipBehavior: Clip.none,
        children: <Widget>[
          if (!(isFirst && isLast))
            Positioned(
              key: ValueKey<String>('$lineKeyPrefix${entry.id}'),
              left: (railWidth - lineWidth) / 2,
              width: lineWidth,
              top: isFirst ? entry.anchor : 0,
              bottom: isLast ? null : 0,
              height: isLast ? entry.anchor : null,
              child: ColoredBox(color: lineColor),
            ),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : itemGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: railWidth,
                  // 高为锚点的两倍、节点居中：节点中心正好落在锚点上。
                  height: entry.anchor * 2,
                  child: node == null ? null : Center(child: node),
                ),
                Expanded(child: entry.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
