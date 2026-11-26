import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';
import 'package:node_diary/ui/widgets/page_header.dart';

/// 日历页头：与其他 Tab 同一个 [PageHeader]（64dp，铺到状态栏，叠在内容
/// 之上，因此必须放在页面 Stack 里），标题就是当前月份（年视图下是年份）。
///
/// - 点标题：月 / 周视图进入年视图，年视图打开日期选择器（[onPickDate]）；
///   标题随翻月方向滑入，与下方网格翻页同向；
/// - 翻月：手机上左右滑网格，页头不放箭头（窄屏放不下标题 + 箭头 + 四个
///   操作）；[showArrows] 为 true（宽窗口、桌面键鼠）时在操作前放上一页 /
///   下一页；
/// - 右侧依次为纪念日、筛选、显示选项与回到今天。
///
/// 仅组合 UI，月份切换与选日仍由调用方负责。
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
    this.showArrows = false,
  });

  /// 不含状态栏的高度，与其他 Tab 的页头一致。
  static const double height = PageHeader.contentHeight;

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

  /// 标题的提示（月视图下为“查看全年”，年视图下为“选择日期”）。
  final String? titleTooltip;

  /// 上一页/下一页按钮的提示；为 null 时为“上个月/下个月”。
  final String? previousTooltip;
  final String? nextTooltip;

  /// 是否在操作按钮前放上一页 / 下一页。
  final bool showArrows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return PageHeader(
      title: title,
      titleChild: _MonthTitle(title: title, month: month),
      titleTrailing: FaIcon(
        FontAwesomeIcons.angleDown,
        size: 14,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTitleTap: onPickDate,
      titleTooltip: titleTooltip,
      actions: <Widget>[
        if (showArrows) ...<Widget>[
          IconButton(
            tooltip: previousTooltip ?? l10n.autoT0184,
            onPressed: onPreviousMonth,
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          ),
          IconButton(
            tooltip: nextTooltip ?? l10n.autoT0185,
            onPressed: onNextMonth,
            icon: const FaIcon(FontAwesomeIcons.angleRight, size: 18),
          ),
          const SizedBox(width: 4),
        ],
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
        if (onOpenDisplayOptions != null) ...<Widget>[
          IconButton(
            tooltip: l10n.calendarDisplayOptionsTooltip,
            onPressed: onOpenDisplayOptions,
            icon: const FaIcon(FontAwesomeIcons.sliders, size: 18),
          ),
          const SizedBox(width: 4),
        ],
        IconButton.filledTonal(
          style: AppGlassField.tonalButtonStyle(context),
          tooltip: l10n.autoT0180,
          onPressed: onJumpToToday,
          icon: const FaIcon(FontAwesomeIcons.calendarDay, size: 18),
        ),
      ],
    );
  }
}

/// 月份标题：随翻月方向滑动交替（下一月从右侧进入、上一月从左侧进入），与网格
/// 翻页同时长同方向；此前标题在网格滑到一半时瞬间换字。方向未知（首帧、选择
/// 日期跳转到同一月）时只做淡入淡出。字样继承页头标题（DefaultTextStyle）。
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
        // 新旧标题都贴着起始边叠放：标题紧跟着下拉箭头，长短不同时不会
        // 先居中再跳回。
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: AlignmentDirectional.centerStart,
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
        child: Text(widget.title, key: currentKey),
      ),
    );
  }
}
