part of 'diary_card_style.dart';

// DiaryCardStyle 的 JSON 读写工具。
//
// 解码逐字段容错：缺失、类型不符、未知枚举名、NaN/无穷或越界的数值，只让
// 该字段回退到默认值（数值越界夹到边界），不连累同一对象里的其他字段。
// 编码是稀疏的：只写与该字段默认值不同的项（见 [DiaryCardStyle] 的说明）。

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
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

bool _bool(Object? raw, bool fallback) => raw is bool ? raw : fallback;

double _double(Object? raw, double fallback, DiaryCardRange range) {
  if (raw is! num || !raw.isFinite) {
    return fallback;
  }
  return range.clamp(raw.toDouble());
}

int _int(Object? raw, int fallback, DiaryCardRange range) {
  if (raw is! num || !raw.isFinite) {
    return fallback;
  }
  return range.clampInt(raw.round());
}

/// 解析自定义颜色：接受 `#RRGGBB`、`#AARRGGBB`（不带 # 亦可）或 ARGB 整数。
/// 一律强制为不透明——透明度由各颜色位的强度字段单独表达。
int? _argb(Object? raw) {
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

String _hex(int argb) =>
    '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Map<String, dynamic>? _map(Object? raw) {
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

/// 区块顺序：丢弃未知名与重复项，再把缺失的区块按默认顺序补在末尾，保证
/// 每个区块恰好出现一次（新版本新增区块时旧配置也能完整渲染）。
List<DiaryCardBlock> _blocks(Object? raw, List<DiaryCardBlock> fallback) {
  if (raw is! List) {
    return fallback;
  }
  final result = <DiaryCardBlock>[];
  for (final item in raw) {
    for (final block in DiaryCardBlock.values) {
      if (block.name == item && !result.contains(block)) {
        result.add(block);
      }
    }
  }
  for (final block in DiaryCardBlock.values) {
    if (!result.contains(block)) {
      result.add(block);
    }
  }
  return List<DiaryCardBlock>.unmodifiable(result);
}

/// 稀疏写入：值与默认值相同则不写。
void _put(Map<String, Object> json, String key, Object value, Object fallback) {
  if (value != fallback) {
    json[key] = value;
  }
}

void _putEnum(Map<String, Object> json, String key, Enum value, Enum fallback) {
  if (value != fallback) {
    json[key] = value.name;
  }
}

/// 子对象稀疏写入：与默认值完全相同时整个键都不写。
void _putObject(
  Map<String, Object> json,
  String key,
  Map<String, Object> encoded,
) {
  if (encoded.isNotEmpty) {
    json[key] = encoded;
  }
}
