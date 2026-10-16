/// 样式模型（卡片样式、预览页样式）共用的 JSON 读写工具与数值范围。
///
/// 解码逐字段容错：缺失、类型不符、未知枚举名、NaN/无穷或越界的数值，只让
/// 该字段回退到默认值（数值越界夹到边界），不连累同一对象里的其他字段。
/// 编码是稀疏的：只写与该字段默认值不同的项。
library;

/// 一个数值字段的闭区间与步进。
///
/// 同一份范围被三处共用：解码时夹紧（旧版本或手改的样式码越界只回退到
/// 边界）、设置页滑块的 min/max/divisions、渲染层的二次夹紧。
class StyleRange {
  const StyleRange(this.min, this.max, this.step);

  final double min;
  final double max;
  final double step;

  double clamp(double value) => value.clamp(min, max).toDouble();

  int clampInt(int value) => value.clamp(min.round(), max.round()).toInt();

  /// 滑块分段数；步进不能整除区间时向最近整数取整。
  int get divisions => ((max - min) / step).round();
}

abstract final class StyleJson {
  static T enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
    if (raw is! String) {
      return fallback;
    }
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return fallback;
  }

  static bool boolean(Object? raw, bool fallback) =>
      raw is bool ? raw : fallback;

  static double number(Object? raw, double fallback, StyleRange range) {
    if (raw is! num || !raw.isFinite) {
      return fallback;
    }
    return range.clamp(raw.toDouble());
  }

  static int integer(Object? raw, int fallback, StyleRange range) {
    if (raw is! num || !raw.isFinite) {
      return fallback;
    }
    return range.clampInt(raw.round());
  }

  /// 解析自定义颜色：接受 `#RRGGBB`、`#AARRGGBB`（不带 # 亦可）或 ARGB 整数。
  /// 一律强制为不透明——透明度由各颜色位的强度字段单独表达。
  static int? argb(Object? raw) {
    int? value;
    if (raw is int) {
      value = raw;
    } else if (raw is String) {
      var hex = raw.trim();
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      if ((hex.length == 6 || hex.length == 8) &&
          RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
        value = int.tryParse(hex, radix: 16);
      }
    }
    if (value == null || value < 0 || value > 0xFFFFFFFF) {
      return null;
    }
    return 0xFF000000 | (value & 0x00FFFFFF);
  }

  static String hex(int argb) =>
      '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static Map<String, dynamic>? map(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return <String, dynamic>{
        for (final entry in raw.entries)
          if (entry.key is String) entry.key as String: entry.value,
      };
    }
    return null;
  }

  /// 稀疏写入：值与默认值相同则不写。
  static void put(
    Map<String, Object> json,
    String key,
    Object value,
    Object fallback,
  ) {
    if (value != fallback) {
      json[key] = value;
    }
  }

  static void putEnum(
    Map<String, Object> json,
    String key,
    Enum value,
    Enum fallback,
  ) {
    if (value != fallback) {
      json[key] = value.name;
    }
  }

  /// 可选颜色的稀疏写入（以 `#RRGGBB` 保存）。
  static void putColor(
    Map<String, Object> json,
    String key,
    int? value,
    int? fallback,
  ) {
    if (value != null && value != fallback) {
      json[key] = hex(value);
    }
  }

  /// 子对象稀疏写入：与默认值完全相同时整个键都不写。
  static void putObject(
    Map<String, Object> json,
    String key,
    Map<String, Object> encoded,
  ) {
    if (encoded.isNotEmpty) {
      json[key] = encoded;
    }
  }
}
