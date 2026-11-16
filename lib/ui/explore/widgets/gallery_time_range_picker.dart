import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../calendar/models/calendar_display_options.dart';
import '../../calendar/providers/calendar_display_options_provider.dart';
import '../../calendar/widgets/calendar_month_grid.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../models/gallery_time_selection.dart';
import 'gallery_time_range_cells.dart';

/// 媒体画廊“时间选择”二级菜单里的内联日历。
///
/// 职责：画标题行（“月”“年”两个胶囊）、日期页（固定 6 行，翻月高度不跳）、
/// 盖在日期上的选月 / 选年层与底部的清除 / 取消 / 确定；状态与交互规则全在
/// [GalleryTimeSelection]。确定、清除后关掉整个菜单。
///
/// 一周从哪天开始、是否显示农历小字与休/班跟随日历页的显示选项
/// （`calendarDisplayOptionsProvider`），与日历页一致。
///
/// 翻页：日期页左右翻一个月、选年页翻 12 年。前后两页一起画在当前页两侧，
/// 手指拖动时整排跟着移动；松手超过四分之一页宽或甩得够快时整页滑过去，
/// 动画结束后才提交翻页（不先跳页再补动画），否则弹回原位。
///
/// 菜单收起请求（点外部、点遮罩、系统返回）经 [backHandle]：停在选月 /
/// 选年层时先退回日期页、恢复打开前的选择，菜单不关。
class GalleryTimeRangePicker extends ConsumerStatefulWidget {
  const GalleryTimeRangePicker({
    super.key,
    required this.initialRange,
    required this.onApply,
    required this.onClear,
    required this.backHandle,
  });

  /// 交给二级菜单的 `onCollapseRequest`：日历挂载期间由它接手收起请求。
  final GalleryTimePickerBackHandle backHandle;

  /// 已应用的时间范围；非空时底部多一个“清除”。
  final DateTimeRange? initialRange;
  final ValueChanged<DateTimeRange> onApply;
  final VoidCallback onClear;

  /// 菜单内容宽度：七列日期格每格约 36。
  static const double width = 272;
  static const double _hPadding = 10;

  /// 相邻两个月之间的留白：贴在一起时分不清哪几天属于哪个月。
  static const double _pageGap = 16;

  @override
  ConsumerState<GalleryTimeRangePicker> createState() =>
      _GalleryTimeRangePickerState();
}

/// 页面与菜单里那份日历之间的接头：二级菜单的内容在打开时才建，页面拿不到
/// 它的 State，于是由日历挂载时把“退回日期页”登记到这里、卸载时撤掉。二级
/// 菜单收回途中又打开时，新旧两份日历先后登记，撤销只撤自己那一份。
class GalleryTimePickerBackHandle {
  bool Function()? _handler;

  void _attach(bool Function() handler) => _handler = handler;

  void _detach(bool Function() handler) {
    if (_handler == handler) _handler = null;
  }

  /// 有日历挂着且它退了一级时返回 true（菜单这次不收回）。
  bool handle() => _handler?.call() ?? false;
}

class _GalleryTimeRangePickerState extends ConsumerState<GalleryTimeRangePicker>
    with SingleTickerProviderStateMixin {
  late final GalleryTimeSelection _selection = GalleryTimeSelection(
    initial: widget.initialRange,
    now: DateTime.now(),
  );

  /// 松手后的整页滑动 / 回弹：value 0→1 映射成 [_slideFrom]→[_slideTo]。
  late final AnimationController _slide = AnimationController(vsync: this)
    ..addStatusListener(_onSlideStatus);
  double _drag = 0;
  double _slideFrom = 0;
  double _slideTo = 0;

  /// 松手时决定的翻页方向；滑动动画完成后据此提交。
  bool? _pendingForward;

  /// 当前这一层一页的宽度（含页间留白），由布局时量出。
  double _pageExtent = GalleryTimeRangePicker.width;

  double get _offset {
    if (!_slide.isAnimating) return _drag;
    final t = ExpressiveMotion.effects.transform(_slide.value);
    return _slideFrom + (_slideTo - _slideFrom) * t;
  }

  @override
  void initState() {
    super.initState();
    widget.backHandle._attach(_backToDays);
  }

  @override
  void dispose() {
    widget.backHandle._detach(_backToDays);
    _slide.dispose();
    super.dispose();
  }

  /// 菜单要收起时先问这里：在选月 / 选年层时退回日期页并返回 true。
  bool _backToDays() {
    if (!_selection.backToDays()) return false;
    setState(() {});
    return true;
  }

  void _update(void Function(GalleryTimeSelection selection) change) {
    setState(() => change(_selection));
  }

  void _apply() {
    final range = _selection.result;
    if (range == null) return;
    widget.onApply(range);
    ExpressiveMenuAnchorState.maybeOf(context)?.close();
  }

  void _clear() {
    widget.onClear();
    ExpressiveMenuAnchorState.maybeOf(context)?.close();
  }

  void _cancel() {
    if (_backToDays()) return;
    ExpressiveMenuAnchorState.maybeOf(context)?.close();
  }

  void _onDragStart(DragStartDetails details) {
    final current = _offset;
    _slide.stop();
    _drag = current;
    _pendingForward = null;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_selection.canPage) return;
    setState(() => _drag += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_selection.canPage) return;
    final velocity = details.primaryVelocity ?? 0;
    final threshold = _pageExtent / 4;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // 往左拖（偏移为负）看后一页；从右往左书写时反过来。
    final towardEnd = _drag.abs() >= threshold ? _drag < 0 : velocity < 0;
    final turn = _drag.abs() >= threshold || velocity.abs() > 350;
    _slideFrom = _drag;
    _slideTo = turn ? (towardEnd ? -_pageExtent : _pageExtent) : 0;
    _pendingForward = turn ? towardEnd != rtl : null;
    _drag = 0;
    _slide
      ..duration = ExpressiveMotion.durationNonZero(
        context,
        ExpressiveMotion.medium,
      )
      ..forward(from: 0);
    setState(() {});
  }

  void _onSlideStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final forward = _pendingForward;
    _pendingForward = null;
    setState(() {
      _slide.value = 0;
      _slideFrom = 0;
      _slideTo = 0;
      if (forward != null) _selection.page(forward: forward);
    });
  }

  @override
  Widget build(BuildContext context) {
    final options =
        ref.watch(calendarDisplayOptionsProvider).value ??
        const CalendarDisplayOptions();
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final lunar = CalendarMonthGrid.showsLunar(options.lunarMode, locale);
    final holidays = CalendarMonthGrid.showsHolidays(
      options.holidayMode,
      locale,
    );
    final firstWeekday = CalendarMonthGrid.firstWeekdayOf(
      options.weekStart,
      MaterialLocalizations.of(context),
    );
    return SizedBox(
      width: GalleryTimeRangePicker.width,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GalleryTimeRangePicker._hPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(locale),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: AnimatedBuilder(
                animation: _slide,
                builder: (BuildContext context, Widget? _) => _buildBody(
                  locale: locale,
                  lunar: lunar,
                  holidays: holidays,
                  firstWeekday: firstWeekday,
                ),
              ),
            ),
            const SizedBox(height: 2),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  String _monthName(String locale, int month) =>
      DateFormat.LLL(locale).format(DateTime(2000, month));

  String _yearName(String locale, int year) =>
      DateFormat.y(locale).format(DateTime(year));

  Widget _buildHeader(String locale) {
    final l10n = context.l10n;
    final s = _selection;
    final visible = s.visibleMonth;
    final months = s.monthRange;
    final years = s.yearRange;
    final String monthLabel;
    if (s.allMonthsSelected) {
      // “全部”里的月份跟随可见月，翻日期页时实时更新。
      monthLabel = l10n.exploreGalleryTimeAllMonths(
        _monthName(locale, visible.month),
      );
    } else if (months != null && months.$1 != months.$2) {
      monthLabel = l10n.exploreGalleryTimeSpan(
        _monthName(locale, months.$1),
        _monthName(locale, months.$2),
      );
    } else {
      monthLabel = _monthName(locale, months?.$1 ?? visible.month);
    }
    final String yearLabel;
    if (!s.allMonthsSelected && years != null && years.$1 != years.$2) {
      yearLabel = l10n.exploreGalleryTimeSpan(
        _yearName(locale, years.$1),
        _yearName(locale, years.$2),
      );
    } else if (!s.allMonthsSelected && years != null) {
      yearLabel = _yearName(locale, years.$1);
    } else {
      // 全部时年份跟随可见年，跨年翻页后随之更新。
      yearLabel = _yearName(locale, visible.year);
    }
    final monthOpen = s.mode == GalleryTimePickerMode.month;
    final yearOpen = s.mode == GalleryTimePickerMode.year;
    return Row(
      children: <Widget>[
        Expanded(
          child: GalleryTimeHeaderChip(
            label: monthLabel,
            active: monthOpen || s.allMonthsSelected,
            open: monthOpen,
            onTap: () => _update((s) => s.toggleMonthPicker()),
            onLongPress: () => _update((s) => s.longPressMonthHeader()),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GalleryTimeHeaderChip(
            label: yearLabel,
            active: yearOpen,
            open: yearOpen,
            onTap: () => _update((s) => s.toggleYearPicker()),
            onLongPress: () => _update((s) => s.longPressYearHeader()),
          ),
        ),
      ],
    );
  }

  /// 日期页垫在下面；选月 / 选年时它压暗、不响应，新的一层从上方滑入盖住。
  Widget _buildBody({
    required String locale,
    required bool lunar,
    required bool holidays,
    required int firstWeekday,
  }) {
    final mode = _selection.mode;
    final onDays = mode == GalleryTimePickerMode.day;
    Widget dayPage(DateTime month) => _DayPage(
      month: month,
      selection: _selection,
      firstWeekday: firstWeekday,
      lunar: lunar,
      holidays: holidays,
      onTap: (DateTime day) => _update((s) => s.tapDay(day)),
      onLongPress: (DateTime day) => _update((s) => s.longPressDay(day)),
    );
    final visible = _selection.visibleMonth;
    final days = onDays
        ? _Pager(
            offset: _offset,
            gap: GalleryTimeRangePicker._pageGap,
            onExtent: (double extent) => _pageExtent = extent,
            pageAt: (int delta) =>
                dayPage(DateTime(visible.year, visible.month + delta)),
          )
        : dayPage(visible);
    final overlay = switch (mode) {
      GalleryTimePickerMode.month => GalleryGridPage(
        cellAt: (int i) => GalleryGridCell(
          label: _monthName(locale, i + 1),
          mark: _selection.monthMark(i + 1),
          onTap: () => _update((s) => s.pickMonth(i + 1)),
          onLongPress: () => _update((s) => s.longPressMonth(i + 1)),
        ),
      ),
      GalleryTimePickerMode.year => _Pager(
        offset: _offset,
        gap: 0,
        onExtent: (double extent) => _pageExtent = extent,
        pageAt: (int delta) {
          final first = _selection.currentYearPageStart + delta * 12;
          return GalleryGridPage(
            cellAt: (int i) => GalleryGridCell(
              label: '${first + i}',
              mark: _selection.yearMark(first + i),
              onTap: () => _update((s) => s.pickYear(first + i)),
              onLongPress: () => _update((s) => s.longPressYear(first + i)),
            ),
          );
        },
      ),
      GalleryTimePickerMode.day => const SizedBox.shrink(),
    };
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    return Stack(
      children: <Widget>[
        AnimatedOpacity(
          opacity: onDays ? 1 : 0.35,
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          curve: ExpressiveMotion.effects,
          child: IgnorePointer(ignoring: !onDays, child: days),
        ),
        Positioned.fill(
          child: ClipRect(
            child: IgnorePointer(
              ignoring: onDays,
              child: AnimatedSlide(
                offset: onDays ? const Offset(0, -0.18) : Offset.zero,
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.medium,
                ),
                curve: ExpressiveMotion.spatial,
                child: AnimatedOpacity(
                  opacity: onDays ? 0 : 1,
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  curve: ExpressiveMotion.effects,
                  // 比菜单再深一档、带描边与投影，像一层盖在日期上的小面板。
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: light
                          ? colors.surfaceContainerLow
                          : colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: colors.shadow.withValues(
                            alpha: light ? 0.06 : 0.18,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(child: overlay),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final muted = TextButton.styleFrom(
      foregroundColor: colors.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
    );
    return Row(
      children: <Widget>[
        if (widget.initialRange != null)
          TextButton.icon(
            onPressed: _clear,
            icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
            label: Text(l10n.exploreGalleryTimeClear),
            style: muted,
          ),
        const Spacer(),
        TextButton(
          onPressed: _cancel,
          style: muted,
          child: Text(l10n.commonCancel),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: _selection.result == null ? null : _apply,
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}

/// 前一页、当前页、后一页并排（页间留 [gap]），整体平移 [offset]；裁掉
/// 两侧露出的部分。量出的页宽（含留白）经 [onExtent] 交给翻页阈值。
class _Pager extends StatelessWidget {
  const _Pager({
    required this.offset,
    required this.gap,
    required this.onExtent,
    required this.pageAt,
  });

  final double offset;
  final double gap;
  final ValueChanged<double> onExtent;
  final Widget Function(int delta) pageAt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final advance = constraints.maxWidth + gap;
        onExtent(advance);
        final direction = Directionality.of(context) == TextDirection.rtl
            ? -1.0
            : 1.0;
        return ClipRect(
          child: Stack(
            children: <Widget>[
              for (final delta in const <int>[-1, 1])
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(offset + delta * direction * advance, 0),
                    child: pageAt(delta),
                  ),
                ),
              Transform.translate(offset: Offset(offset, 0), child: pageAt(0)),
            ],
          ),
        );
      },
    );
  }
}

/// 一个月的日期页：星期栏 + 固定 6 行 42 格（不足的补空格，翻月高度不跳）。
class _DayPage extends StatelessWidget {
  const _DayPage({
    required this.month,
    required this.selection,
    required this.firstWeekday,
    required this.lunar,
    required this.holidays,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime month;
  final GalleryTimeSelection selection;
  final int firstWeekday;
  final bool lunar;
  final bool holidays;
  final ValueChanged<DateTime> onTap;
  final ValueChanged<DateTime> onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final narrow = MaterialLocalizations.of(context).narrowWeekdays;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cellHeight = galleryDayCellHeight(lunar: lunar);
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday - firstWeekday + 7) % 7;
    Widget row(List<Widget> cells) => Row(
      children: <Widget>[for (final cell in cells) Expanded(child: cell)],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        row(<Widget>[
          for (var i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Text(
                  // narrowWeekdays 从周日开始。
                  narrow[(firstWeekday + i) % 7],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ]),
        for (var week = 0; week < 6; week++)
          row(<Widget>[
            for (var i = 0; i < 7; i++)
              Builder(
                builder: (BuildContext context) {
                  final dayNumber = week * 7 + i - leading + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return SizedBox(height: cellHeight);
                  }
                  final day = DateTime(month.year, month.month, dayNumber);
                  return GalleryDayCell(
                    day: day,
                    mark: selection.dayMark(day),
                    isToday: day == today,
                    showLunar: lunar,
                    showHolidays: holidays,
                    onTap: () => onTap(day),
                    onLongPress: () => onLongPress(day),
                  );
                },
              ),
          ]),
      ],
    );
  }
}
