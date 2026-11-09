// 待办的改动类工具：完成、取消完成、编辑步骤、删除（删除先确认）。
//
// 写库只经待办的 DB ops，规则与待办页一致：完成重复待办经 `completeTodos`
// 推到下一次并插入这一次的已完成副本，撤销倒序 `undoTodoCompletion`；取消
// 完成只写完成时间一列，撤销经 `restoreTodoCompletedAt` 写回；步骤整列写回。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../models/ai_tool_subject.dart';
import 'ai_tool.dart';
import 'ai_tool_todo_parts.dart';

class CompleteTodosTool extends AiTool {
  const CompleteTodosTool();

  @override
  String get name => 'complete_todos';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Mark to-dos (by id) as done. Repeating to-dos move to their next date.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 100),
    },
    required: <String>['ids'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolCompleteTodos(ids is List ? ids.length : 1);
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final completions = await context.database.completeTodos(
      (args['ids']! as List).cast<String>(),
      now: context.now,
    );
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'completed': completions.length},
      summary: context.l10n.aiToolDone,
      subjects: [
        for (final completion in completions) aiTodoSubject(completion.before),
      ],
      undo: <String, Object?>{
        'completions': [
          for (final completion in completions)
            <String, Object?>{
              'before': completion.before.toJson(),
              'copyId': ?completion.copyId,
              'nextDue': ?completion.nextDue?.millisecondsSinceEpoch,
            },
        ],
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final database = container.read(appDatabaseProvider);
    // 倒序撤：后完成的先撤，重复待办的副本与原行的先后关系不会乱。
    for (final raw in (data['completions']! as List).reversed) {
      final map = (raw as Map).cast<String, Object?>();
      final nextDue = map['nextDue'];
      await database.undoTodoCompletion(
        TodoCompletion(
          before: TodoRow.fromJson(
            (map['before']! as Map).cast<String, dynamic>(),
          ),
          copyId: map['copyId'] as String?,
          nextDue: nextDue is int
              ? DateTime.fromMillisecondsSinceEpoch(nextDue)
              : null,
        ),
      );
    }
  }
}

class ReopenTodosTool extends AiTool {
  const ReopenTodosTool();

  @override
  String get name => 'reopen_todos';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Mark completed to-dos (by id) as not done again. A completed '
      'occurrence of a repeating to-do becomes a separate open to-do.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 100),
    },
    required: <String>['ids'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolReopenTodos(ids is List ? ids.length : 1);
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final rows = await aiTodosByIds(
      database,
      (args['ids']! as List).cast<String>(),
    );
    final done = [
      for (final row in rows)
        if (row.completedAt != null) row,
    ];
    if (done.isEmpty) {
      throw const AiToolFailure('None of these to-dos is completed.');
    }
    for (final row in done) {
      await database.uncompleteTodo(row.todoId);
    }
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'reopened': done.length},
      summary: context.l10n.aiToolDone,
      subjects: [for (final row in done) aiTodoSubject(row)],
      undo: <String, Object?>{
        'completed': <String, Object?>{
          for (final row in done)
            row.todoId: row.completedAt!.millisecondsSinceEpoch,
        },
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final database = container.read(appDatabaseProvider);
    final completed = (data['completed']! as Map).cast<String, Object?>();
    for (final MapEntry(:key, :value) in completed.entries) {
      await database.restoreTodoCompletedAt(
        key,
        DateTime.fromMillisecondsSinceEpoch(value! as int),
      );
    }
  }
}

class EditTodoStepsTool extends AiTool {
  const EditTodoStepsTool();

  @override
  String get name => 'edit_todo_steps';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      "Edit one to-do's steps (sub-tasks): add new ones, check or uncheck, "
      'or remove. Existing steps are named by their id or exact title.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'id': AiStringSchema(description: 'The to-do id.'),
      'add_steps': AiArraySchema(
        items: AiStringSchema(maxLength: TodoStep.maxTitleLength),
        maxItems: TodoStep.maxSteps,
      ),
      'check_steps': AiArraySchema(items: AiStringSchema()),
      'uncheck_steps': AiArraySchema(items: AiStringSchema()),
      'remove_steps': AiArraySchema(items: AiStringSchema()),
    },
    required: <String>['id'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolEditTodoSteps;

  @override
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) {
    final todo = subjects
        .where((subject) => subject.kind == AiSubjectKind.todo)
        .firstOrNull;
    return todo == null
        ? label(l10n, args)
        : l10n.aiToolEditTodoStepsOf(todo.title);
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final id = args['id']! as String;
    final row = await database.getTodo(id);
    if (row == null) throw AiToolFailure('No to-do with id $id.');
    final before = decodeTodoSteps(row.steps);
    var steps = [...before];

    /// 按 id 或标题（不分大小写）找步骤，找不到就报错并列出现有步骤。
    String resolve(String ref) {
      final wanted = ref.trim();
      for (final step in steps) {
        if (step.id == wanted) return step.id;
      }
      for (final step in steps) {
        if (step.title.toLowerCase() == wanted.toLowerCase()) return step.id;
      }
      throw AiToolFailure(
        'No step "$ref". Steps: '
        '${steps.isEmpty ? '(none)' : steps.map((s) => '${s.id}: ${s.title}').join('; ')}.',
      );
    }

    List<String> refs(String key) => [
      for (final ref in args[key] as List? ?? const []) resolve(ref as String),
    ];
    final removed = refs('remove_steps').toSet();
    final checked = refs('check_steps').toSet();
    final unchecked = refs('uncheck_steps').toSet();
    if (checked.intersection(unchecked).isNotEmpty) {
      throw const AiToolFailure('A step cannot be both checked and unchecked.');
    }
    steps = [
      for (final step in steps)
        if (!removed.contains(step.id))
          checked.contains(step.id)
              ? step.copyWith(done: true)
              : unchecked.contains(step.id)
              ? step.copyWith(done: false)
              : step,
    ];
    steps = aiTodoNewSteps(steps, [
      for (final title in args['add_steps'] as List? ?? const [])
        title as String,
    ]);
    if (encodeTodoSteps(steps) == encodeTodoSteps(before)) {
      throw const AiToolFailure('Nothing to change.');
    }
    await database.setTodoSteps(id, steps);
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'steps': [
          for (final step in steps)
            <String, Object?>{
              'id': step.id,
              'title': step.title,
              'done': step.done,
            },
        ],
      },
      summary: context.l10n.aiToolDone,
      subjects: [aiTodoSubject(row)],
      undo: <String, Object?>{'id': id, 'steps': encodeTodoSteps(before)},
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
        .setTodoSteps(
          data['id']! as String,
          decodeTodoSteps(data['steps'] as String?),
        );
  }
}

class DeleteTodosTool extends AiTool {
  const DeleteTodosTool();

  @override
  String get name => 'delete_todos';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.destructive;

  @override
  String get description => 'Delete to-dos (by id). The user confirms first.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 100),
    },
    required: <String>['ids'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolDeleteTodos(ids is List ? ids.length : 1);
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final rows = await aiTodosByIds(
      context.database,
      (args['ids']! as List).cast<String>(),
    );
    final titles = [for (final row in rows) row.title];
    return AiToolPreview(
      title: label(context.l10n, args),
      lines: [...titles.take(8), if (titles.length > 8) '…'],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final rows = await context.database.deleteTodos(
      (args['ids']! as List).cast<String>(),
    );
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'deleted': rows.length},
      summary: context.l10n.aiToolDone,
      subjects: [for (final row in rows) aiTodoSubject(row)],
      undo: <String, Object?>{
        'rows': [for (final row in rows) row.toJson()],
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) => container
      .read(appDatabaseProvider)
      .restoreTodos(aiTodoRows(data['rows']));
}
