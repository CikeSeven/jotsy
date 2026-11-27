/// 清单分区的口径（纯函数，无 IO）。
///
/// 分区是清单内部的一层：定义（id、名称、先后）存在清单行的
/// `metadata.sections`，一条待办属于哪个分区存在它自己的
/// `metadata.sectionId`。都不另设表、不升 schema，随各自的行原样同步与备份。
///
/// 认不出的分区（被删掉、或待办移到了别的清单）一律按“未分区”显示；待办
/// 移回原清单时又回到原来的分区（分区 id 全局唯一，不会错认）。
library;

import 'package:meta/meta.dart';

import 'todo_rules.dart';

/// 清单里的一个分区。
@immutable
class TodoSection {
  const TodoSection({required this.id, required this.name});

  final String id;
  final String name;

  TodoSection copyWith({String? name}) =>
      TodoSection(id: id, name: name ?? this.name);

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is TodoSection && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'TodoSection($id, $name)';
}

abstract final class TodoSections {
  /// 清单 `metadata` 里的键。
  static const String listKey = 'sections';

  /// 待办 `metadata` 里的键。
  static const String todoKey = 'sectionId';

  /// 一个清单最多几个分区。
  static const int maxPerList = 30;

  /// 分区名最长几个字。
  static const int maxNameLength = 40;

  /// 规整分区名：去首尾空白、中间空白折成一个空格、截到 [maxNameLength]；
  /// 为空时为 null。
  static String? normalizeName(String raw) {
    var name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length > maxNameLength) name = name.substring(0, maxNameLength);
    return name.isEmpty ? null : name;
  }

  static String? _cachedRaw;
  static List<TodoSection> _cached = const <TodoSection>[];

  /// 从清单 `metadata` 的 JSON 原文读出分区（坏条目、重复 id 丢掉）。行上的
  /// “清单 · 分区”每行每次构建都会读，按原文记住上一次的结果。
  static List<TodoSection> ofList(String? raw) {
    if (raw == null || !raw.contains('"$listKey"')) {
      return const <TodoSection>[];
    }
    if (raw == _cachedRaw) return _cached;
    final sections = fromMetadata(decodeTodoMetadata(raw));
    _cachedRaw = raw;
    return _cached = sections;
  }

  /// 从解码后的清单 `metadata` 读出分区。
  static List<TodoSection> fromMetadata(Map<String, Object?> metadata) {
    final raw = metadata[listKey];
    if (raw is! List) return const <TodoSection>[];
    final seen = <String>{};
    final out = <TodoSection>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final id = item['id'];
      final name = item['name'];
      if (id is! String || id.isEmpty || name is! String) continue;
      final normalized = normalizeName(name);
      if (normalized == null || !seen.add(id)) continue;
      out.add(TodoSection(id: id, name: normalized));
      if (out.length == maxPerList) break;
    }
    return List<TodoSection>.unmodifiable(out);
  }

  /// 把 [sections] 写进清单 `metadata`（只动这一个键）；为空时去掉这个键。
  static void writeInto(
    Map<String, Object?> metadata,
    List<TodoSection> sections,
  ) {
    if (sections.isEmpty) {
      metadata.remove(listKey);
    } else {
      metadata[listKey] = <Map<String, Object?>>[
        for (final section in sections) section.toJson(),
      ];
    }
  }

  /// 待办所在的分区 id（`metadata.sectionId`）；没有时为 null。不判断这个
  /// 分区还在不在，调用方按清单的分区认。
  static String? idOfTodo(String? todoMetadata) {
    if (todoMetadata == null || !todoMetadata.contains('"$todoKey"')) {
      return null;
    }
    final id = decodeTodoMetadata(todoMetadata)[todoKey];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// 待办在 [sections] 里的分区；不在任何一个里（未分区、认不出）时为 null。
  static TodoSection? of(String? todoMetadata, List<TodoSection> sections) {
    if (sections.isEmpty) return null;
    final id = idOfTodo(todoMetadata);
    if (id == null) return null;
    for (final section in sections) {
      if (section.id == id) return section;
    }
    return null;
  }
}
