// 按数据种类的计数（不可变、按值比较）：“以哪边为准”对话框的明细与完成
// 摘要里日记以外的变化。由 lan_sync_engine_mapping.dart 从引擎的按实体计数
// 换算而来，界面只认这里的种类。

import 'package:flutter/foundation.dart';

/// 界面上区分的数据种类（显示顺序即声明顺序）。
///
/// 日记本含它的收录（成员与书序）与书架顺序，模板含“我的模板”的顺序；
/// 设置含标签顺序与功能开关。
enum LanSyncItemKind {
  diaries,
  tags,
  notebooks,
  comments,
  templates,
  anniversaries,
  dayMoods,
  settings,
}

/// 各种类的数量；只存大于 0 的项。
@immutable
class LanSyncItemCounts {
  factory LanSyncItemCounts(Map<LanSyncItemKind, int> counts) =>
      LanSyncItemCounts._(
        Map<LanSyncItemKind, int>.unmodifiable(<LanSyncItemKind, int>{
          for (final kind in LanSyncItemKind.values)
            if ((counts[kind] ?? 0) > 0) kind: counts[kind]!,
        }),
      );

  const LanSyncItemCounts._(this._counts);

  static const LanSyncItemCounts empty = LanSyncItemCounts._(
    <LanSyncItemKind, int>{},
  );

  final Map<LanSyncItemKind, int> _counts;

  int operator [](LanSyncItemKind kind) => _counts[kind] ?? 0;

  /// 按显示顺序的非零项。
  Iterable<MapEntry<LanSyncItemKind, int>> get entries => _counts.entries;

  int get total => _counts.values.fold(0, (sum, count) => sum + count);

  int get diaries => this[LanSyncItemKind.diaries];

  /// 日记以外的合计。
  int get others => total - diaries;

  bool get isEmpty => _counts.isEmpty;

  /// 去掉日记一项。
  LanSyncItemCounts get withoutDiaries => LanSyncItemCounts(
    <LanSyncItemKind, int>{..._counts}..remove(LanSyncItemKind.diaries),
  );

  LanSyncItemCounts operator +(LanSyncItemCounts other) => LanSyncItemCounts(
    <LanSyncItemKind, int>{
      for (final kind in LanSyncItemKind.values) kind: this[kind] + other[kind],
    },
  );

  @override
  bool operator ==(Object other) =>
      other is LanSyncItemCounts && mapEquals(other._counts, _counts);

  @override
  int get hashCode => Object.hashAll(
    _counts.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}
