// 待办清单的改动类工具：新建、改名、删除（删除连同其中的待办，先确认）。
//
// 写库只经 `_AppDatabaseTodoListOps`；清单的颜色与图标保持原样（AI 只按
// 名称管理清单，样式由用户在清单管理里改）。撤销：
// - 新建：清单里已经放了待办时先报冲突；用户仍要撤销时把那些待办移回收集箱
//   再删清单（不能因为撤销一个“新建”把用户之后记的待办一起删掉）；
// - 改名：改回原名（期间被删掉了就算了）；
// - 删除：清单与其中的待办按快照原样放回（`restoreTodoList`）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../models/ai_tool_subject.dart';
import 'ai_tool.dart';
import 'ai_tool_todo_parts.dart';

/// 清单名称的长度上限（与表的约束一致）。
const int _maxListName = 50;

/// 按名称找清单（不分大小写）；找不到时报错并列出现有清单。
Future<TodoListRow> _listNamed(AppDatabase database, String name) async {
  final id = await aiTodoListId(database, name);
  final list = id == null ? null : await database.getTodoList(id);
  if (list == null) {
    throw const AiToolFailure('Name a to-do list; the inbox is not a list.');
  }
  return list;
}

/// 已有同名清单（不分大小写，[except] 除外）时报错。
Future<void> _checkFreeName(
  AppDatabase database,
  String name, {
  String? except,
}) async {
  final taken = (await database.getTodoLists()).any(
    (list) =>
        list.listId != except &&
        list.name.toLowerCase() == name.trim().toLowerCase(),
  );
  if (taken) throw AiToolFailure('A to-do list named "$name" already exists.');
  if (name.trim().toLowerCase() == aiTodoInboxName.toLowerCase()) {
    throw AiToolFailure('"$name" is the name of the inbox.');
  }
}

class CreateTodoListTool extends AiTool {
  const CreateTodoListTool();

  @override
  String get name => 'create_todo_list';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description => 'Create a to-do list.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'name': AiStringSchema(maxLength: _maxListName),
    },
    required: <String>['name'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolCreateTodoList('${args['name'] ?? ''}');

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final name = (args['name']! as String).trim();
    await _checkFreeName(database, name);
    final id = await database.createTodoList(name: name);
    return AiToolOutcome(
      data: <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [AiToolSubject.todoList(id, name)],
      undo: <String, Object?>{'id': id},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final database = container.read(appDatabaseProvider);
    final id = data['id']! as String;
    final members = await database.getTodoIdsInList(id);
    if (members.isNotEmpty) {
      if (!force) throw const AiUndoConflict();
      await database.setTodosListId(members, null);
    }
    await database.deleteTodoList(id);
  }
}

class RenameTodoListTool extends AiTool {
  const RenameTodoListTool();

  @override
  String get name => 'rename_todo_list';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description => 'Rename a to-do list.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'name': AiStringSchema(description: 'Current name.'),
      'new_name': AiStringSchema(maxLength: _maxListName),
    },
    required: <String>['name', 'new_name'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolRenameTodoList('${args['new_name'] ?? ''}');

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final list = await _listNamed(database, args['name']! as String);
    final next = (args['new_name']! as String).trim();
    if (next == list.name) throw const AiToolFailure('Nothing to change.');
    await _checkFreeName(database, next, except: list.listId);
    await database.updateTodoList(
      list.listId,
      name: next,
      colorKey: list.colorKey,
      iconKey: list.iconKey,
    );
    return AiToolOutcome(
      data: <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [AiToolSubject.todoList(list.listId, next)],
      undo: <String, Object?>{'id': list.listId, 'name': list.name},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final database = container.read(appDatabaseProvider);
    final list = await database.getTodoList(data['id']! as String);
    if (list == null) return;
    await database.updateTodoList(
      list.listId,
      name: data['name']! as String,
      colorKey: list.colorKey,
      iconKey: list.iconKey,
    );
  }
}

class DeleteTodoListTool extends AiTool {
  const DeleteTodoListTool();

  @override
  String get name => 'delete_todo_list';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.destructive;

  @override
  String get description =>
      'Delete a to-do list together with all its to-dos (open and '
      'completed). The user confirms first. To keep the to-dos, move them '
      'with update_todos before deleting.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{'name': AiStringSchema()},
    required: <String>['name'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolDeleteTodoList('${args['name'] ?? ''}');

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final list = await _listNamed(database, args['name']! as String);
    final count = await database.countTodosInList(list.listId);
    return AiToolPreview(
      title: context.l10n.aiToolDeleteTodoList(list.name),
      lines: [if (count > 0) context.l10n.aiToolDeleteTodoListCount(count)],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final list = await _listNamed(database, args['name']! as String);
    final deletion = await database.deleteTodoList(list.listId);
    if (deletion == null) {
      throw const AiToolFailure('The list is already gone.');
    }
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'deleted_todos': deletion.todos.length,
      },
      summary: context.l10n.aiToolDone,
      subjects: [AiToolSubject.todoList(list.listId, list.name)],
      undo: <String, Object?>{
        'list': deletion.list.toJson(),
        'todos': [for (final row in deletion.todos) row.toJson()],
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    await container
        .read(appDatabaseProvider)
        .restoreTodoList(
          TodoListDeletion(
            list: TodoListRow.fromJson(
              (data['list']! as Map).cast<String, dynamic>(),
            ),
            todos: aiTodoRows(data['todos']),
          ),
        );
  }
}
