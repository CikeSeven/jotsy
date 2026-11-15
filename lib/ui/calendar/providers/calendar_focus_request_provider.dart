import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// 一次“让日历选中某天”的请求。[serial] 每次请求加一，同一天连续请求也能
/// 被监听到。
@immutable
class CalendarFocusRequest {
  const CalendarFocusRequest(this.serial, this.day);

  final int serial;
  final DateTime day;

  @override
  bool operator ==(Object other) =>
      other is CalendarFocusRequest &&
      other.serial == serial &&
      other.day == day;

  @override
  int get hashCode => Object.hash(serial, day);
}

/// 日历页之外请求选中某天（点桌面小组件的日期）：日历页监听到就回到月视图、
/// 选中这天并翻到所在的月份。日历页还没建好时（冷启动、刚切过去）由它在
/// 初始化时经 `fireImmediately` 接住，处理后 [consume]。调用方负责先切到
/// 日历 Tab。只在内存里，测试无需替换。
class CalendarFocusRequestNotifier extends Notifier<CalendarFocusRequest?> {
  @override
  CalendarFocusRequest? build() => null;

  void request(DateTime day) => state = CalendarFocusRequest(
    (state?.serial ?? 0) + 1,
    DateUtils.dateOnly(day),
  );

  /// 日历页处理完后置回 null：之后重建的日历页不会再跳到这一天。
  void consume() => state = null;
}

final calendarFocusRequestProvider =
    NotifierProvider<CalendarFocusRequestNotifier, CalendarFocusRequest?>(
      CalendarFocusRequestNotifier.new,
    );
