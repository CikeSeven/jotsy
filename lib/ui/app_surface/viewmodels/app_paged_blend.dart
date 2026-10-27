import 'package:flutter/foundation.dart';

/// 相邻两页之间的背景插值：[lower] 页不透明地画在下面，[upper] 页以
/// [upperOpacity] 叠在上面。静止时两者相同、[upperOpacity] 为 0。
@immutable
class AppPagedBlend {
  const AppPagedBlend(this.lower, this.upper, this.upperOpacity);

  /// 按小数页码 [page] 求插值（[pageCount] 页，页码夹到有效范围）：
  /// 0.3 即 70% 第 0 页 + 30% 第 1 页。
  factory AppPagedBlend.at(double page, int pageCount) {
    if (pageCount <= 1 || page.isNaN) return const AppPagedBlend(0, 0, 0);
    final clamped = page.clamp(0.0, (pageCount - 1).toDouble());
    final lower = clamped.floor();
    final upper = clamped.ceil();
    return AppPagedBlend(lower, upper, upper == lower ? 0 : clamped - lower);
  }

  final int lower;
  final int upper;
  final double upperOpacity;

  @override
  bool operator ==(Object other) =>
      other is AppPagedBlend &&
      other.lower == lower &&
      other.upper == upper &&
      other.upperOpacity == upperOpacity;

  @override
  int get hashCode => Object.hash(lower, upper, upperOpacity);

  @override
  String toString() => 'AppPagedBlend($lower → $upper @ $upperOpacity)';
}
