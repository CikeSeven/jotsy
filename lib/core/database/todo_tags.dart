/// 待办标签的口径（纯函数，无 IO）。
///
/// 待办标签与日记标签**完全无关**：不在 `tags` 表里，没有标签顺序、颜色与
/// 建议，日记侧（标签管理、标签栏、标签搜索、探索页、同步的标签顺序）看
/// 不到它们，待办侧也看不到日记标签。一条待办的标签是 `metadata.tags`
/// 里的字符串数组，随这一行原样同步与备份，不另设表、不升 schema。
///
/// 一个标签“存在”就是至少有一条待办（含已完成的）带着它；名称不分大小写
/// 视为同一个，显示时保留写下时的写法。
library;

import 'todo_rules.dart';

abstract final class TodoTags {
  /// `metadata` 里的键。
  static const String metadataKey = 'tags';

  /// 一条待办最多几个标签。
  static const int maxPerTodo = 10;

  /// 标签名最长几个字（UTF-16 码元）。
  static const int maxLength = 24;

  static final RegExp _spaces = RegExp(r'\s+');

  /// 规整一个标签名：去首尾空白与开头的 `@` / `＠` / `#` / `＃`，中间的空白
  /// 换成 `_`（快速新建里 `@标签` 写到空白为止，带空格的名字写不出来），
  /// 截到 [maxLength]（不切开代理对）；规整后为空时为 null。
  static String? normalize(String raw) {
    var name = raw.trim();
    while (name.isNotEmpty && '@＠#＃'.contains(name[0])) {
      name = name.substring(1).trimLeft();
    }
    name = name.replaceAll(_spaces, '_');
    if (name.length > maxLength) {
      var end = maxLength;
      final unit = name.codeUnitAt(end - 1);
      if (unit >= 0xD800 && unit <= 0xDBFF) end--;
      name = name.substring(0, end);
    }
    return name.isEmpty ? null : name;
  }

  /// 规整一组：逐个 [normalize]，不分大小写去重（保留第一次出现的写法），
  /// 至多 [maxPerTodo] 个。
  static List<String> normalizeAll(Iterable<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      final name = normalize(item);
      if (name == null || !seen.add(keyOf(name))) continue;
      out.add(name);
      if (out.length == maxPerTodo) break;
    }
    return List<String>.unmodifiable(out);
  }

  /// 比较用的键：不分大小写。
  static String keyOf(String name) => name.toLowerCase();

  static bool same(String a, String b) => keyOf(a) == keyOf(b);

  /// [tags] 里是否有 [name]（不分大小写）。
  static bool contains(Iterable<String> tags, String name) {
    final key = keyOf(name);
    return tags.any((tag) => keyOf(tag) == key);
  }

  /// 从解码后的 `metadata` 读出标签：不是字符串的条目丢掉，再按
  /// [normalizeAll] 规整（同步或导入来的数据也可能不规整）。
  static List<String> fromMetadata(Map<String, Object?> metadata) {
    final raw = metadata[metadataKey];
    if (raw is! List) return const <String>[];
    return normalizeAll(raw.whereType<String>());
  }

  /// 从 `metadata` 的 JSON 原文读出标签；原文里没有这个键时不解码（列表
  /// 每行每次构建都会读，绝大多数行没有标签）。
  static List<String> ofMetadataText(String? raw) {
    if (raw == null || !raw.contains('"$metadataKey"')) return const <String>[];
    return fromMetadata(decodeTodoMetadata(raw));
  }

  /// 把 [tags] 写进 `metadata`（只动这一个键）；为空时去掉这个键。
  static void writeInto(Map<String, Object?> metadata, List<String> tags) {
    if (tags.isEmpty) {
      metadata.remove(metadataKey);
    } else {
      metadata[metadataKey] = List<String>.of(tags);
    }
  }
}

/// 一个待办标签的用量（[TodoTags] 口径下同名的合在一起）。
class TodoTagUsage {
  const TodoTagUsage({
    required this.name,
    required this.openCount,
    required this.totalCount,
    required this.lastUsedAt,
  });

  /// 显示用的写法：最近改过的那条待办上的写法。
  final String name;

  /// 带着它的未完成待办数。
  final int openCount;

  /// 带着它的全部待办数（含已完成的与重复待办的已完成副本）。
  final int totalCount;

  /// 带着它的待办里最近一次修改的时刻（“最近用过”的排序）。
  final DateTime lastUsedAt;

  @override
  bool operator ==(Object other) =>
      other is TodoTagUsage &&
      other.name == name &&
      other.openCount == openCount &&
      other.totalCount == totalCount &&
      other.lastUsedAt == lastUsedAt;

  @override
  int get hashCode => Object.hash(name, openCount, totalCount, lastUsedAt);

  @override
  String toString() => 'TodoTagUsage($name, $openCount/$totalCount)';
}
