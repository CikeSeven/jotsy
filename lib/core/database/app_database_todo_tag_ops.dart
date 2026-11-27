part of 'app_database.dart';

/// 待办标签的读写（口径见 `todo_tags.dart`：存在 `metadata.tags`，与日记
/// 标签互不相通）。
///
/// 约定：
/// 1. 每个方法各在一个事务里读改写，只动 `metadata` 里的 `tags` 这一个键，
///    别的键（推迟次数、重复计数、认不出的新键）原样保留；
/// 2. 标签本来就一样的行不写，不平白刷新 `updated_at`（理由同批量写入，见
///    `_AppDatabaseTodoBatchOps`）；
/// 3. 批量方法（加标签、改名 / 合并、删除）返回真正改动了的行（改动前的样
///    子），撤销经 `restoreTodoFields(before, TodoBatchField.tags)`。
mixin _AppDatabaseTodoTagOps on _$AppDatabase, _AppDatabaseTodoQueries {
  /// 粗筛：`metadata` 里出现过 `"tags":` 的行（JSON 由 `jsonEncode` 写出，
  /// 键与冒号之间没有空白）；再在 Dart 里解码精确判断。
  static const String _tagsLike = '%"${TodoTags.metadataKey}":%';

  /// 把待办 [todoId] 的标签换成 [tags]（规整后）。
  Future<void> setTodoTags(String todoId, List<String> tags) {
    final next = TodoTags.normalizeAll(tags);
    return transaction(() async {
      final row = await getTodo(todoId);
      if (row == null) return;
      await _writeTodoTags(row, next, DateTime.now());
    });
  }

  /// 把 [todoIds] 的标签都换成 [tags]（AI 助手的 `update_todos`）；标签本来就
  /// 一样的不写。返回改动前的行。
  Future<List<TodoRow>> setTodosTags(
    Iterable<String> todoIds,
    List<String> tags,
  ) {
    final ids = todoIds.toSet().toList(growable: false);
    if (ids.isEmpty) return Future<List<TodoRow>>.value(const <TodoRow>[]);
    final next = TodoTags.normalizeAll(tags);
    return transaction(() async {
      final now = DateTime.now();
      final changed = <TodoRow>[];
      for (final row in await (select(
        todos,
      )..where((t) => t.todoId.isIn(ids))).get()) {
        if (await _writeTodoTags(row, next, now)) changed.add(row);
      }
      return changed;
    });
  }

  /// 给 [todoIds] 都加上标签 [tag]（已有的、已满 [TodoTags.maxPerTodo] 个的
  /// 不动）。
  Future<List<TodoRow>> addTodosTag(Iterable<String> todoIds, String tag) {
    final name = TodoTags.normalize(tag);
    final ids = todoIds.toSet().toList(growable: false);
    if (name == null || ids.isEmpty) {
      return Future<List<TodoRow>>.value(const <TodoRow>[]);
    }
    return transaction(() async {
      final now = DateTime.now();
      final changed = <TodoRow>[];
      for (final row in await (select(
        todos,
      )..where((t) => t.todoId.isIn(ids))).get()) {
        final tags = TodoTags.ofMetadataText(row.metadata);
        if (TodoTags.contains(tags, name) ||
            tags.length >= TodoTags.maxPerTodo) {
          continue;
        }
        if (await _writeTodoTags(row, <String>[...tags, name], now)) {
          changed.add(row);
        }
      }
      return changed;
    });
  }

  /// 把标签 [from] 改名为 [to]（不分大小写）；有的待办已经带着 [to] 时两者
  /// 合并成一个（即合并标签）。名字只差大小写时也算改名（换写法）。
  Future<List<TodoRow>> renameTodoTag(String from, String to) {
    final name = TodoTags.normalize(to);
    if (name == null) return Future<List<TodoRow>>.value(const <TodoRow>[]);
    return _rewriteTag(from, (List<String> tags) {
      final out = <String>[];
      for (final tag in tags) {
        final replaced = TodoTags.same(tag, from) ? name : tag;
        if (!TodoTags.contains(out, replaced)) out.add(replaced);
      }
      return out;
    });
  }

  /// 从所有待办上去掉标签 [name]。
  Future<List<TodoRow>> deleteTodoTag(String name) =>
      _rewriteTag(name, (List<String> tags) {
        return <String>[
          for (final tag in tags)
            if (!TodoTags.same(tag, name)) tag,
        ];
      });

  Future<List<TodoRow>> _rewriteTag(
    String name,
    List<String> Function(List<String> tags) rewrite,
  ) {
    return transaction(() async {
      final now = DateTime.now();
      final changed = <TodoRow>[];
      for (final row in await _todosTagged(name)) {
        final tags = TodoTags.ofMetadataText(row.metadata);
        if (await _writeTodoTags(row, rewrite(tags), now)) changed.add(row);
      }
      return changed;
    });
  }

  /// 带着标签 [name] 的待办（含已完成的）。
  Future<List<TodoRow>> _todosTagged(String name) async {
    final rows = await (select(
      todos,
    )..where((t) => t.metadata.like(_tagsLike))).get();
    return <TodoRow>[
      for (final row in rows)
        if (TodoTags.contains(TodoTags.ofMetadataText(row.metadata), name)) row,
    ];
  }

  /// 写回一行的标签；与现在的一样时不写，返回是否写了。
  Future<bool> _writeTodoTags(
    TodoRow row,
    List<String> tags,
    DateTime now,
  ) async {
    final map = decodeTodoMetadata(row.metadata);
    final next = TodoTags.normalizeAll(tags);
    final current = TodoTags.fromMetadata(map);
    if (_sameTags(current, next) &&
        (map[TodoTags.metadataKey] != null) == next.isNotEmpty) {
      return false;
    }
    TodoTags.writeInto(map, next);
    await (update(todos)..where((t) => t.id.equals(row.id))).write(
      TodosCompanion(metadata: Value(jsonEncode(map)), updatedAt: Value(now)),
    );
    return true;
  }

  static bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 全部待办标签及用量，按名称排序（不分大小写）。任何待办变化都会重算：
  /// 粗筛后只解码带标签的行，量级与待办总数相当，不另建索引。
  Stream<List<TodoTagUsage>> watchTodoTags() {
    final query = select(todos)..where((t) => t.metadata.like(_tagsLike));
    return query.watch().map((List<TodoRow> rows) {
      final byKey = <String, _TagTally>{};
      for (final row in rows) {
        final tags = TodoTags.ofMetadataText(row.metadata);
        for (final tag in tags) {
          final tally = byKey.putIfAbsent(TodoTags.keyOf(tag), _TagTally.new);
          tally.add(tag, row);
        }
      }
      final usages = <TodoTagUsage>[
        for (final tally in byKey.values) tally.usage,
      ];
      usages.sort(
        (a, b) => TodoTags.keyOf(a.name).compareTo(TodoTags.keyOf(b.name)),
      );
      return List<TodoTagUsage>.unmodifiable(usages);
    });
  }
}

class _TagTally {
  String name = '';
  int open = 0;
  int total = 0;
  DateTime? last;

  void add(String tag, TodoRow row) {
    total++;
    if (row.completedAt == null) open++;
    final at = row.updatedAt;
    if (last == null || at.isAfter(last!)) {
      last = at;
      name = tag;
    }
  }

  TodoTagUsage get usage => TodoTagUsage(
    name: name,
    openCount: open,
    totalCount: total,
    lastUsedAt: last!,
  );
}
