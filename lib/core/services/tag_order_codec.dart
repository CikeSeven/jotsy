import 'package:node_diary/core/database/app_database.dart';

/// 将标签顺序编码为持久化字符串（按 id 逗号拼接）。
String encodeTagOrder(List<int> tagIds) {
  final normalized = <int>[];
  final seen = <int>{};
  for (final id in tagIds) {
    if (id <= 0 || !seen.add(id)) {
      continue;
    }
    normalized.add(id);
  }
  return normalized.join(',');
}

/// 将持久化字符串解析为标签 id 顺序。
List<int> decodeTagOrder(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <int>[];
  }
  final result = <int>[];
  final seen = <int>{};
  for (final segment in raw.split(',')) {
    final id = int.tryParse(segment.trim());
    if (id == null || id <= 0 || !seen.add(id)) {
      continue;
    }
    result.add(id);
  }
  return result;
}

/// 按“用户自定义顺序 + 名称兜底排序”输出标签列表。
///
/// 规则：
/// 1. 在顺序表里的标签优先，按顺序表相对位置排序；
/// 2. 未配置顺序的新标签按名称升序排在后面；
/// 3. 顺序表中残留的无效 id 自动忽略。
List<Tag> sortTagsByCustomOrder(List<Tag> tags, List<int> orderedTagIds) {
  if (tags.length <= 1) {
    return List<Tag>.from(tags);
  }

  final orderIndex = <int, int>{};
  for (var i = 0; i < orderedTagIds.length; i++) {
    orderIndex[orderedTagIds[i]] = i;
  }

  final sorted = List<Tag>.from(tags);
  sorted.sort((Tag a, Tag b) {
    final aIndex = orderIndex[a.id];
    final bIndex = orderIndex[b.id];
    final aInOrder = aIndex != null;
    final bInOrder = bIndex != null;
    if (aInOrder && bInOrder) {
      return aIndex.compareTo(bIndex);
    }
    if (aInOrder) {
      return -1;
    }
    if (bInOrder) {
      return 1;
    }
    return a.name.compareTo(b.name);
  });
  return sorted;
}
