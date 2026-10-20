import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_top_bar_surface.dart';

/// 日历的 Expressive 双行页头。月份控制单独成行，避免窄屏或英文标题
/// 与居中的月份导航重叠。仅组合 UI，月份切换与选日仍由调用方负责。
///
/// 底由 [HomeTopBarSurface] 画（含状态栏区域）：实色时与原来的 surface 色块
/// 一致；首页顶栏用玻璃时换成玻璃，日历内容从页头后透出并被模糊。
///
/// 月份行可按 [collapsedExtent] 收起（页面里由 `CalendarHeaderSliver` 随滚动
/// 给出）：标题栏不动，月份行整体上移、从标题栏下缘收进去，页头高度同步
/// 减少；完全收起时只剩状态栏 + 标题栏。
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
    this.onOpenAnniversaries,
    this.filterActive = false,
    this.titleTooltip,
    this.previousTooltip,
    this.nextTooltip,
    this.collapsedExtent = 0,
  });

  /// 标题栏（“日历” + 操作按钮）的高度，月份行收起后仍然保留。
  static const double titleBarHeight = 64;

  /// 月份行（上一页 / 标题 / 下一页）的高度，也是它最多能收起的高度。
  static const double monthBarHeight = 48;

  /// 完整展开时不含状态栏的内容高度。
  static const double contentHeight = titleBarHeight + monthBarHeight;

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

  /// 打开纪念日列表；为 null 时不显示该按钮。
  final VoidCallback? onOpenAnniversaries;

  /// 筛选生效中：按钮切换为选中态并带一个小圆点，离开卡片也能看出网格
  /// 是筛选后的结果。
  final bool filterActive;

  /// 标题按钮的提示（月视图下为“查看全年”，年视图下为“选择日期”）。
  final String? titleTooltip;

  /// 上一页/下一页按钮的提示；为 null 时为“上个月/下个月”。
  final String? previousTooltip;
  final String? nextTooltip;

  /// 月份行已被收起的高度：0 为完整显示，[monthBarHeight] 为只剩标题栏；
  /// 超出范围的值会被夹取。
  final double collapsedExtent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final collapsed = collapsedExtent.clamp(0.0, monthBarHeight);
    // 完全收起后月份行仍挂在树上（网格还露在下方时照样能左右翻月，月份标题
    // 的滑动方向要接得上）。裁切到零高度后读屏与点按都会自动略过它，但键盘
    // / 方向键的焦点遍历不看裁切，要另外排除，焦点才不会落到看不见的按钮上。
    final monthBarHidden = collapsed >= monthBarHeight;
    return HomeTopBarSurface(
      solidColor: theme.colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top,
          16,
          0,
        ),
        child: Column(
          // 高度由两行决定：放在页面 Stack 或 sliver 里都不会撑满。
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: titleBarHeight,
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
                  if (onOpenAnniversaries != null)
                    IconButton(
                      tooltip: l10n.anniversaryListTitle,
                      onPressed: onOpenAnniversaries,
                      icon: const FaIcon(FontAwesomeIcons.heart, size: 17),
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
                        child: const FaIcon(FontAwesomeIcons.filter, size: 17),
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
                    icon: const FaIcon(FontAwesomeIcons.calendarDay, size: 18),
                  ),
                ],
              ),
            ),
            // 月份行始终按完整高度布局、底部对齐，只裁出还露着的那一段：
            // 收起时整行上移，像被内容带着滚到标题栏下面，而不是被压扁。
            SizedBox(
              height: monthBarHeight - collapsed,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.bottomCenter,
                  minHeight: monthBarHeight,
                  maxHeight: monthBarHeight,
                  child: ExcludeFocus(
                    excluding: monthBarHidden,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: previousTooltip ?? l10n.autoT0184,
                          onPressed: onPreviousMonth,
                          icon: const FaIcon(
                            FontAwesomeIcons.angleLeft,
                            size: 18,
                          ),
                        ),
                        Expanded(child: _buildTitleButton()),
                        IconButton(
                          tooltip: nextTooltip ?? l10n.autoT0185,
                          onPressed: onNextMonth,
                          icon: const FaIcon(
                            FontAwesomeIcons.angleRight,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
