/// 可选文本标准化：去掉首尾空白，空串视为 null。
///
/// 日记元数据（地点、天气、心情、封面路径等）统一按“没填”处理空白输入，
/// 避免把空串写进 metadata 或草稿。
String? normalizeOptionalText(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
