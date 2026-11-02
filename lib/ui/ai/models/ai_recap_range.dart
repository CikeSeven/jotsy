// 回顾的时间范围与日记范围（纯数据，不碰数据库）。
//
// 时间范围一律是本地时间的 [start, end)：周从“每周起始日”算起（与日历、
// 写作目标同一口径），月、年按自然月 / 年。“本周 / 本月 / 今年”的终点是
// 这段时间的末尾而不是此刻——之后再写的日记也属于这一期，重新生成时会
// 带上。日记本范围只存业务 id 与名称快照（本子改名或删掉后，旧回顾仍显示
// 当时的名称）。

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 回顾的预设范围。
enum AiRecapPreset {
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisYear,
  custom,
}

/// 一段回顾范围：[start]（含）到 [end]（不含），本地时间的零点。
@immutable
class AiRecapRange {
  const AiRecapRange({
    required this.preset,
    required this.start,
    required this.end,
  });

  /// 按预设推出范围。[firstWeekday] 为 `DateTime.monday`..`DateTime.sunday`。
  /// [custom] 没有固定范围，这里退回本周（调用方另行给出日期）。
  factory AiRecapRange.preset(
    AiRecapPreset preset, {
    required DateTime now,
    int firstWeekday = DateTime.monday,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final offset = (today.weekday - firstWeekday + 7) % 7;
    final weekStart = DateTime(today.year, today.month, today.day - offset);
    DateTime days(DateTime from, int count) =>
        DateTime(from.year, from.month, from.day + count);
    return switch (preset) {
      AiRecapPreset.thisWeek || AiRecapPreset.custom => AiRecapRange(
        preset: preset == AiRecapPreset.custom
            ? AiRecapPreset.thisWeek
            : preset,
        start: weekStart,
        end: days(weekStart, 7),
      ),
      AiRecapPreset.lastWeek => AiRecapRange(
        preset: preset,
        start: days(weekStart, -7),
        end: weekStart,
      ),
      AiRecapPreset.thisMonth => AiRecapRange(
        preset: preset,
        start: DateTime(today.year, today.month),
        end: DateTime(today.year, today.month + 1),
      ),
      AiRecapPreset.lastMonth => AiRecapRange(
        preset: preset,
        start: DateTime(today.year, today.month - 1),
        end: DateTime(today.year, today.month),
      ),
      AiRecapPreset.thisYear => AiRecapRange(
        preset: preset,
        start: DateTime(today.year),
        end: DateTime(today.year + 1),
      ),
    };
  }

  /// 自定义范围：[first] 与 [last] 两天都含在内。
  factory AiRecapRange.days(DateTime first, DateTime last) {
    final a = DateTime(first.year, first.month, first.day);
    final b = DateTime(last.year, last.month, last.day);
    final (from, to) = a.isAfter(b) ? (b, a) : (a, b);
    return AiRecapRange(
      preset: AiRecapPreset.custom,
      start: from,
      end: DateTime(to.year, to.month, to.day + 1),
    );
  }

  final AiRecapPreset preset;
  final DateTime start;
  final DateTime end;

  /// 范围里的最后一天（显示用）。
  DateTime get lastDay => DateTime(end.year, end.month, end.day - 1);

  /// 跨了多少天（按日历日）。
  int get dayCount => DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

  @override
  bool operator ==(Object other) =>
      other is AiRecapRange &&
      other.preset == preset &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(preset, start, end);
}

/// 回顾的日记范围：全部日记，或某一本可见的日记本（手动本或智能本）。
@immutable
class AiRecapScope {
  const AiRecapScope.all() : notebookId = null, notebookName = null;

  const AiRecapScope.notebook({
    required String this.notebookId,
    required String this.notebookName,
  });

  final String? notebookId;

  /// 生成时的名称快照。
  final String? notebookName;

  bool get isAll => notebookId == null;

  /// 存进 `ai_results.scope` 的 JSON（带上预设，供列表显示）。
  String encode(AiRecapPreset preset) => jsonEncode(<String, Object?>{
    'preset': preset.name,
    'notebookId': ?notebookId,
    'notebookName': ?notebookName,
  });

  /// 从存储读回：认不出的一律当作全部日记。
  static ({AiRecapScope scope, AiRecapPreset? preset}) decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        final id = json['notebookId'];
        final name = json['notebookName'];
        final presetName = json['preset'];
        AiRecapPreset? preset;
        for (final value in AiRecapPreset.values) {
          if (value.name == presetName) preset = value;
        }
        return (
          scope: id is String && id.isNotEmpty
              ? AiRecapScope.notebook(
                  notebookId: id,
                  notebookName: name is String ? name : '',
                )
              : const AiRecapScope.all(),
          preset: preset,
        );
      }
    } on FormatException {
      // 落到下面。
    }
    return (scope: const AiRecapScope.all(), preset: null);
  }

  @override
  bool operator ==(Object other) =>
      other is AiRecapScope && other.notebookId == notebookId;

  @override
  int get hashCode => notebookId.hashCode;
}
