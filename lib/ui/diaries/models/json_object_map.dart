/// 把任意 JSON 解码结果归一为 `Map<String, Object?>`，只保留可再次编码的值。
///
/// 地址组件等结构来自外部服务或旧版本草稿，键可能不是字符串、值可能混入
/// 运行时对象；写回草稿或 metadata 前先清洗，避免编码失败。非 Map 返回 null。
Map<String, Object?>? parseJsonObjectMap(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key?.toString();
    if (key == null || key.isEmpty) {
      continue;
    }
    normalized[key] = _normalizeJsonValue(entry.value);
  }
  return normalized;
}

/// 递归清洗动态值：基本类型原样保留，Map/List 逐层清洗，其余转为字符串。
Object? _normalizeJsonValue(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Map) {
    return parseJsonObjectMap(value);
  }
  if (value is List) {
    return value.map(_normalizeJsonValue).toList(growable: false);
  }
  return value.toString();
}
