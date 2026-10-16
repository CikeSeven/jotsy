import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 日历的 Expressive 双行页头。月份控制单独成行，避免窄屏或英文标题
/// 与居中的月份导航重叠。仅组合 UI，月份切换与选日仍由调用方负责。
class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    super.key,
    required this.title,
    this.month,
    required this.onJumpToToday,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onPickDate,
    this.onOpenDisplayOptions,
    this.onOpenFilter,
    this.filterActive = false,
    this.titleTooltip,
    this.previousTooltip,
    this.nextTooltip,
  });

  static const double contentHeight = 112;

  final String title;

  /// 标题对应的月份；提供时月份标题随翻月方向滑入，与下方网格翻页同向。
  final DateTime? month;
  final VoidCallback onJumpToToday;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickDate;

  /// 打开日历显示选项面板；为 null 时不显示该按钮。
  final VoidCallback? onOpenDisplayOptions;

  /// 打开筛选面板；为 null 时不显示该按钮。
  final VoidCallback? onOpenFilter;

  /// 筛选生效中：按钮切换为选中态并带一个小圆点，离开卡片也能看出网格
  /// 是筛选后的结果。
  final bool filterActive;

  /// 标题按钮的提示（月视图下为“查看全年”，年视图下为“选择日期”）。
  final String? titleTooltip;

  /// 上一页/下一页按钮的提示；为 null 时为“上个月/下个月”。
  final String? previousTooltip;
  final String? nextTooltip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top,
            16,
            0,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.autoT0183,
                        style: theme.textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onOpenFilter != null)
                      IconButton(
                        tooltip: l10n.calendarFilterTooltip,
                        isSelected: filterActive,
                        onPressed: onOpenFilter,
                        icon: Badge(
                          isLabelVisible: filterActive,
                          smallSize: 7,
                          // 选中态图标已是 primary，圆点用 tertiary 才分得开。
                          backgroundColor: theme.colorScheme.tertiary,
                          child: const FaIcon(
                            FontAwesomeIcons.filter,
                            size: 17,
                          ),
                        ),
                      ),
                    if (onOpenDisplayOptions != null) ...[
                      IconButton(
                        tooltip: l10n.calendarDisplayOptionsTooltip,
                        onPressed: onOpenDisplayOptions,
                        icon: const FaIcon(FontAwesomeIcons.sliders, size: 18),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton.filledTonal(
                      tooltip: l10n.autoT0180,
                      onPressed: onJumpToToday,
                      icon: const FaIcon(
                        FontAwesomeIcons.calendarDay,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: previousTooltip ?? l10n.autoT0184,
                      onPressed: onPreviousMonth,
                      icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
                    ),
                    Expanded(child: _buildTitleButton()),
                    IconButton(
                      tooltip: nextTooltip ?? l10n.autoT0185,
                      onPressed: onNextMonth,
                      icon: const FaIcon(FontAwesomeIcons.angleRight, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleButton() {
    final button = TextButton(
      onPressed: onPickDate,
      child: _MonthTitle(title: title, month: month),
    );
    final tooltip = titleTooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// 月份标题：随翻月方向滑动交替（下一月从右侧进入、上一月从左侧进入），与网格
/// 翻页同时长同方向；此前标题在网格滑到一半时瞬间换字。方向未知（首帧、选择
/// 日期跳转到同一月）时只做淡入淡出。
class _MonthTitle extends StatefulWidget {
  const _MonthTitle({required this.title, required this.month});

  final String title;
  final DateTime? month;

  @override
  State<_MonthTitle> createState() => _MonthTitleState();
}

class _MonthTitleState extends State<_MonthTitle> {
  /// 1：翻到后面的月份；-1：翻到前面的月份；0：方向未知。
  int _direction = 0;

  @override
  void didUpdateWidget(covariant _MonthTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    final month = widget.month;
    final previous = oldWidget.month;
    if (widget.title == oldWidget.title) {
      return;
    }
    _direction = month == null || previous == null || month == previous
        ? 0
        : (month.isAfter(previous) ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) {
    final currentKey = ValueKey<String>(widget.title);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.center,
          children: <Widget>[...previousChildren, ?currentChild],
        ),
        transitionBuilder: (Widget child, Animation<double> animation) {
          // 离开的标题动画从 1 倒放到 0，所以起点取反方向即可向另一侧滑出。
          final incoming = child.key == currentKey;
          final dx = 0.3 * (incoming ? _direction : -_direction);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(dx, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Text(
          widget.title,
          key: currentKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
