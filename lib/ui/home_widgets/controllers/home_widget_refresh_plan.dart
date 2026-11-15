// 小组件什么时候重画（`HomeWidgetSyncController` 用）：快照写入后让哪些种类重画
// （[homeWidgetKindsToRefresh]），以及之后定时重画的时刻（[homeWidgetRedrawTimes]）。
//
// 每次库表变化都会重建快照，但多数改动只碰到一两节：自动保存日记只改日记相关的几节，
// 勾掉一项待办只改「待办」。按节比较上一份与这一份，只让用到变化那几节的种类重画；
// 公共部分（配色、文案、实例配置、语言、应用锁标记等）变了时全部重画。Glance 重画一个
// 种类要把它所有实例重新组合、交给桌面，省下不必要的重画就是省电。

import 'dart:convert';

import '../../../core/services/home_widgets/home_widget_kind.dart';
import '../viewmodels/home_widget_today_section.dart'
    show kHomeWidgetDayHorizon;

/// 各种类读快照里的哪些数据节（与原生各小组件的读法一致）。
const Map<HomeWidgetKind, Set<String>> _sectionsOf =
    <HomeWidgetKind, Set<String>>{
      HomeWidgetKind.quickCapture: <String>{'today'},
      HomeWidgetKind.today: <String>{'today'},
      HomeWidgetKind.anniversary: <String>{'anniversaries'},
      HomeWidgetKind.moodCalendar: <String>{'calendar'},
      HomeWidgetKind.todos: <String>{'todos'},
      HomeWidgetKind.onThisDay: <String>{'onThisDay', 'diaries'},
      HomeWidgetKind.recentDiaries: <String>{'recent', 'diaries'},
      HomeWidgetKind.writingStats: <String>{'stats'},
      HomeWidgetKind.photoMemories: <String>{'photos', 'onThisDay', 'diaries'},
    };

/// 只属于某些种类的数据节；其余顶层字段都算公共部分。
final Set<String> _dataSections = <String>{
  for (final sections in _sectionsOf.values) ...sections,
};

/// 快照按顶层字段拆开、各自编码，供下次比较。
Map<String, String> homeWidgetSnapshotParts(Map<String, Object?> snapshot) =>
    <String, String>{
      for (final entry in snapshot.entries) entry.key: jsonEncode(entry.value),
    };

/// 从 [previous] 到 [next] 要重画的种类（只在 [installed] 里挑）。[previous] 为 null
/// （这次运行第一次写入）时全部重画。
Set<HomeWidgetKind> homeWidgetKindsToRefresh(
  Map<String, String>? previous,
  Map<String, String> next,
  Set<HomeWidgetKind> installed,
) {
  if (previous == null) return installed;
  final changed = <String>{
    for (final key in <String>{...previous.keys, ...next.keys})
      if (previous[key] != next[key]) key,
  };
  if (changed.isEmpty) return const <HomeWidgetKind>{};
  if (changed.any((key) => !_dataSections.contains(key))) return installed;
  return <HomeWidgetKind>{
    for (final kind in installed)
      if (_sectionsOf[kind]!.any(changed.contains)) kind,
  };
}

/// 快速记录的问候换时段的整点（早上 / 下午 / 晚上 / 深夜，原生 `greeting()` 同口径）。
const List<int> _greetingHours = <int>[5, 11, 18, 23];

/// 某种类在 [now] 之后要定时重画的时刻：之后 [kHomeWidgetDayHorizon] 天的零点；快速
/// 记录再加上每天问候换时段的整点。都在整点后几秒，避开系统时钟与闹钟的毫秒级误差
/// 落在前一刻。
List<DateTime> homeWidgetRedrawTimes(HomeWidgetKind kind, DateTime now) {
  final times = <DateTime>[
    for (var day = 1; day <= kHomeWidgetDayHorizon; day++)
      DateTime(now.year, now.month, now.day + day, 0, 0, 5),
  ];
  if (kind == HomeWidgetKind.quickCapture) {
    for (var day = 0; day < kHomeWidgetDayHorizon; day++) {
      for (final hour in _greetingHours) {
        final time = DateTime(now.year, now.month, now.day + day, hour, 0, 5);
        if (time.isAfter(now)) times.add(time);
      }
    }
    times.sort();
  }
  return times;
}
