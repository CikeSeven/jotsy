part of 'diary_card_style.dart';

// DiaryCardStyle 的 JSON 读写工具：通用部分委托给 [StyleJson]（与预览页
// 样式共用），这里只保留简短的库内别名与卡片专有的区块顺序解析。

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    StyleJson.enumByName(values, raw, fallback);

bool _bool(Object? raw, bool fallback) => StyleJson.boolean(raw, fallback);

double _double(Object? raw, double fallback, DiaryCardRange range) =>
    StyleJson.number(raw, fallback, range);

int _int(Object? raw, int fallback, DiaryCardRange range) =>
    StyleJson.integer(raw, fallback, range);

int? _argb(Object? raw) => StyleJson.argb(raw);

String _hex(int argb) => StyleJson.hex(argb);

Map<String, dynamic>? _map(Object? raw) => StyleJson.map(raw);

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

void _put(
  Map<String, Object> json,
  String key,
  Object value,
  Object fallback,
) => StyleJson.put(json, key, value, fallback);

void _putEnum(
  Map<String, Object> json,
  String key,
  Enum value,
  Enum fallback,
) => StyleJson.putEnum(json, key, value, fallback);

void _putObject(
  Map<String, Object> json,
  String key,
  Map<String, Object> encoded,
) => StyleJson.putObject(json, key, encoded);
