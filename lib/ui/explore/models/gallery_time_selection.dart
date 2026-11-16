import 'package:flutter/material.dart' show DateTimeRange;

/// 媒体画廊“时间选择”日历当前显示的一层：日期、盖在日期上的选月或选年。
enum GalleryTimePickerMode { day, month, year }

/// 日期格的选中样子：普通、浅色（单选的一天或范围中段）、深色（范围端点）。
enum GalleryDayMark { none, light, dark }

/// 选月 / 选年格子的样子：普通、当前所在（描边 + 浅底）、范围端点（深色）、
/// 范围中段（浅色）。
enum GalleryGridMark { none, current, endpoint, middle }

/// “时间选择”日历的状态与全部交互规则（纯逻辑，不含界面与文案）。
///
/// 规则（交接自二次开发版本，逐条保留）：
/// - 点日期 = 只选这一天（浅色）；长按一次 = 深色单点，再长按另一天扩成
///   范围（两端深色、中段浅色）；
/// - 选月 / 选年盖在日期上（[mode]），打开前先存一份快照：点取消、点外部、
///   系统返回都恢复快照退回日期，不点“确定”就等于什么也没改；
/// - 长按月份做 1~12 月里的区间（落在当前可见年份）；长按“月”标题在全选
///   （“全部”）与清空之间切换，全部时月标题里的月份跟随可见月、翻页翻到
///   新的一年时所选年份与全年范围随之更新，取消全部时可见月 / 年不回退；
/// - 长按年份做年份区间（月份默认全选，日期跳到起始年 1 月）；长按“年”
///   标题回到所选年份所在的那一页；全部之后再去选年份，全部自动失效；
/// - 日期页左右翻一个月，年份页左右翻 12 年，选月页不翻页；
/// - 重新打开时从已应用的范围还原月 / 年选择的高亮（整年、同年整月）。
class GalleryTimeSelection {
  GalleryTimeSelection({DateTimeRange? initial, required DateTime now})
    : _now = now,
      start = _dateOf(initial?.start),
      end = _dateOf(initial?.end),
      visibleMonth = DateTime(
        (initial?.start ?? now).year,
        (initial?.start ?? now).month,
      ) {
    _restoreFromRange(initial);
  }

  final DateTime _now;

  /// 选中的起止日期（只到天）；[end] 为 null 时只选了 [start] 这一天。
  DateTime? start;
  DateTime? end;

  /// 日期页显示的月份（这个月 1 号）。
  DateTime visibleMonth;
  GalleryTimePickerMode mode = GalleryTimePickerMode.day;

  /// 选年页第一格的年份（3 × 4 = 12 年）；null 为还没打开过选年页。
  int? yearPageStart;

  int? _monthSelStart;
  int? _monthSelEnd;
  int? _yearSelStart;
  int? _yearSelEnd;
  _Snapshot? _snapshot;

  static DateTime? _dateOf(DateTime? d) =>
      d == null ? null : DateTime(d.year, d.month, d.day);

  /// 选好的范围（单选一天时起止同一天）；还没选时为 null，“确定”不可点。
  DateTimeRange? get result {
    final s = start;
    if (s == null) return null;
    final e = end ?? s;
    return e.isBefore(s)
        ? DateTimeRange(start: e, end: s)
        : DateTimeRange(start: s, end: e);
  }

  /// 长按月份选出的月区间（小的在前）；没选时为 null。
  (int, int)? get monthRange => _ordered(_monthSelStart, _monthSelEnd);

  /// 长按年份选出的年区间（小的在前）；没选时为 null。
  (int, int)? get yearRange => _ordered(_yearSelStart, _yearSelEnd);

  /// 1~12 月全选（“全部”）。
  bool get allMonthsSelected => monthRange == (1, 12);

  static (int, int)? _ordered(int? a, int? b) {
    if (a == null || b == null) return null;
    return a <= b ? (a, b) : (b, a);
  }

  int get _yearPageStart => yearPageStart ?? visibleMonth.year - 5;

  /// 选年页现在第一格的年份。
  int get currentYearPageStart => _yearPageStart;

  void _clearGridSelection() {
    _monthSelStart = null;
    _monthSelEnd = null;
    _yearSelStart = null;
    _yearSelEnd = null;
  }

  /// 打开时从已应用的范围还原：整年（1/1–12/31，可跨年）还原成年份区间 +
  /// 全部月份，可见月停在今天所在的月（今年在范围里时）或起始年的 1 月；
  /// 同一年里的整月还原成月份区间。
  void _restoreFromRange(DateTimeRange? range) {
    final s = _dateOf(range?.start);
    final e = _dateOf(range?.end);
    if (s == null || e == null) return;
    if (s.month == 1 && s.day == 1 && e.month == 12 && e.day == 31) {
      _yearSelStart = s.year;
      _yearSelEnd = e.year;
      _monthSelStart = 1;
      _monthSelEnd = 12;
      yearPageStart = s.year;
      final inRange = _now.year >= s.year && _now.year <= e.year;
      visibleMonth = DateTime(
        inRange ? _now.year : s.year,
        inRange ? _now.month : 1,
      );
      return;
    }
    final lastDay = DateTime(e.year, e.month + 1, 0).day;
    if (s.year == e.year && s.day == 1 && e.day == lastDay) {
      _monthSelStart = s.month;
      _monthSelEnd = e.month;
      _yearSelStart = s.year;
      _yearSelEnd = s.year;
      yearPageStart = s.year;
    }
  }

  GalleryDayMark dayMark(DateTime day) {
    final s = start;
    final e = end;
    if (s == null) return GalleryDayMark.none;
    if (e == null) {
      return day == s ? GalleryDayMark.light : GalleryDayMark.none;
    }
    if (day == s || day == e) return GalleryDayMark.dark;
    final (lo, hi) = s.isBefore(e) ? (s, e) : (e, s);
    return day.isAfter(lo) && day.isBefore(hi)
        ? GalleryDayMark.light
        : GalleryDayMark.none;
  }

  GalleryGridMark monthMark(int month) =>
      _gridMark(month, monthRange, visibleMonth.month);

  GalleryGridMark yearMark(int year) =>
      _gridMark(year, yearRange, visibleMonth.year);

  static GalleryGridMark _gridMark(int value, (int, int)? range, int current) {
    if (range != null) {
      final (lo, hi) = range;
      if (value == lo || value == hi) return GalleryGridMark.endpoint;
      if (value > lo && value < hi) return GalleryGridMark.middle;
      return GalleryGridMark.none;
    }
    return value == current ? GalleryGridMark.current : GalleryGridMark.none;
  }

  void tapDay(DateTime day) {
    _clearGridSelection();
    start = _dateOf(day);
    end = null;
  }

  void longPressDay(DateTime day) {
    final d = _dateOf(day)!;
    _clearGridSelection();
    final s = start;
    if (s != null && end != null && s == end) {
      // 已有深色单点：这次长按的是另一端。
      final before = s.isBefore(d);
      start = before ? s : d;
      end = before ? d : s;
    } else {
      start = d;
      end = d;
    }
  }

  /// 按当前可见年份与月区间写起止日期（不动可见月：选月不让日期页跳月）。
  void _applyMonthRange() {
    final range = monthRange;
    if (range == null) return;
    final (lo, hi) = range;
    final year = visibleMonth.year;
    start = DateTime(year, lo);
    end = DateTime(year, hi + 1, 0);
  }

  void longPressMonthHeader() {
    if (allMonthsSelected) {
      // 取消全部：只清选择，可见月 / 年停在翻到的位置。
      _clearGridSelection();
      start = null;
      end = null;
      return;
    }
    _monthSelStart = 1;
    _monthSelEnd = 12;
    _yearSelStart = visibleMonth.year;
    _yearSelEnd = visibleMonth.year;
    _applyMonthRange();
  }

  void longPressMonth(int month) {
    final range = monthRange;
    if (range == null || range.$1 != range.$2) {
      // 没选过或已是完整区间：从这个月重新开始。
      _monthSelStart = month;
      _monthSelEnd = month;
    } else {
      _monthSelEnd = month;
    }
    _yearSelStart = visibleMonth.year;
    _yearSelEnd = visibleMonth.year;
    _applyMonthRange();
  }

  void longPressYear(int year) {
    final range = yearRange;
    if (range == null || range.$1 != range.$2) {
      _yearSelStart = year;
      _yearSelEnd = year;
    } else {
      _yearSelEnd = year;
    }
    _monthSelStart = 1;
    _monthSelEnd = 12;
    final (lo, hi) = yearRange!;
    visibleMonth = DateTime(lo);
    start = DateTime(lo);
    end = DateTime(hi, 12, 31);
  }

  void longPressYearHeader() {
    _dropAllMonths();
    _takeSnapshot();
    yearPageStart = visibleMonth.year - 5;
    mode = GalleryTimePickerMode.year;
  }

  /// 全部之后又去选年份：全部失效，年份从干净的状态开始选。
  void _dropAllMonths() {
    if (!allMonthsSelected) return;
    _clearGridSelection();
    start = null;
    end = null;
  }

  void toggleMonthPicker() {
    if (mode == GalleryTimePickerMode.month) {
      mode = GalleryTimePickerMode.day;
      return;
    }
    _takeSnapshot();
    mode = GalleryTimePickerMode.month;
  }

  void toggleYearPicker() {
    if (mode == GalleryTimePickerMode.year) {
      mode = GalleryTimePickerMode.day;
      return;
    }
    _dropAllMonths();
    _takeSnapshot();
    mode = GalleryTimePickerMode.year;
    // 第一次打开才定位；之后保持上次翻到的那一页。
    yearPageStart ??= visibleMonth.year - 5;
  }

  void pickMonth(int month) {
    visibleMonth = DateTime(visibleMonth.year, month);
    mode = GalleryTimePickerMode.day;
  }

  void pickYear(int year) {
    visibleMonth = DateTime(year, visibleMonth.month);
    mode = GalleryTimePickerMode.day;
  }

  /// 当前这一层能否左右翻页（选月页不翻）。
  bool get canPage => mode != GalleryTimePickerMode.month;

  /// 翻一页：日期页一个月，选年页 12 年。
  void page({required bool forward}) {
    final delta = forward ? 1 : -1;
    switch (mode) {
      case GalleryTimePickerMode.day:
        visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + delta);
        // 全部时翻到新的一年：所选年份与全年范围跟着走，标题与“确定”后的
        // 筛选一致。
        final year = visibleMonth.year;
        if (allMonthsSelected && _yearSelStart != year) {
          _yearSelStart = year;
          _yearSelEnd = year;
          start = DateTime(year);
          end = DateTime(year, 12, 31);
        }
      case GalleryTimePickerMode.month:
        break;
      case GalleryTimePickerMode.year:
        yearPageStart = _yearPageStart + delta * 12;
    }
  }

  /// 选月 / 选年时退回日期并恢复打开前的选择（取消、点外部、系统返回）；
  /// 已在日期页时返回 false，由调用方关掉菜单。
  bool backToDays() {
    if (mode == GalleryTimePickerMode.day) return false;
    _snapshot?.restore(this);
    _snapshot = null;
    mode = GalleryTimePickerMode.day;
    return true;
  }

  void _takeSnapshot() => _snapshot = _Snapshot(this);
}

/// 打开选月 / 选年前的选择，取消时原样恢复。
class _Snapshot {
  _Snapshot(GalleryTimeSelection s)
    : start = s.start,
      end = s.end,
      visibleMonth = s.visibleMonth,
      monthSelStart = s._monthSelStart,
      monthSelEnd = s._monthSelEnd,
      yearSelStart = s._yearSelStart,
      yearSelEnd = s._yearSelEnd;

  final DateTime? start;
  final DateTime? end;
  final DateTime visibleMonth;
  final int? monthSelStart;
  final int? monthSelEnd;
  final int? yearSelStart;
  final int? yearSelEnd;

  void restore(GalleryTimeSelection s) {
    s
      ..start = start
      ..end = end
      ..visibleMonth = visibleMonth
      .._monthSelStart = monthSelStart
      .._monthSelEnd = monthSelEnd
      .._yearSelStart = yearSelStart
      .._yearSelEnd = yearSelEnd;
  }
}
