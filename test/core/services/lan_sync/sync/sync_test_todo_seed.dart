import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:node_diary/core/database/app_database.dart';

DateTime _at(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

/// `seedEveryEntity` 的待办部分：清单与待办的各种形态（JSON 列按应用的键
/// 顺序写入、带新版本的未知字段、坏 JSON、整值的 REAL 顺序）。时间为 Unix 秒。
Future<void> seedTodos(AppDatabase db) async {
  await db
      .into(db.todoLists)
      .insert(
        TodoListsCompanion.insert(
          listId: 'list-1',
          name: 'Groceries',
          colorKey: const Value('teal'),
          iconKey: const Value('cart'),
          sortOrder: const Value(1.5),
          // 更新版本写入的键：同步必须原样保留。
          metadata: const Value('{"z":1,"futureKey":{"b":2,"a":1}}'),
          createdAt: _at(1700006000),
          updatedAt: _at(1700006100),
        ),
      );
  await db
      .into(db.todoLists)
      .insert(
        TodoListsCompanion.insert(
          listId: 'list-2',
          name: 'Broken metadata',
          // 整值的 REAL：规范值必须是 2.0（浮点），不能在 2 与 2.0 之间摇摆。
          sortOrder: const Value(2),
          metadata: const Value('not json'),
          createdAt: _at(1700006000),
          updatedAt: _at(1700006100),
        ),
      );

  await db
      .into(db.todos)
      .insert(
        TodosCompanion.insert(
          todoId: 'todo-full',
          listId: const Value('list-1'),
          title: 'Buy milk',
          note: const Value('2 bottles\nskimmed'),
          priority: const Value(2),
          dueDate: const Value('2026-11-08'),
          dueMinute: const Value(900),
          // 按应用的键顺序写（不是规范顺序），另带一个新版本的提醒种类。
          reminders: Value(
            jsonEncode(<Object?>[
              <String, Object?>{'kind': 'beforeDue', 'minutes': 15},
              <String, Object?>{'kind': 'onDay', 'days': -1, 'minute': 1200},
              <String, Object?>{'kind': 'futureKind', 'x': 1.5},
            ]),
          ),
          repeat: Value(
            jsonEncode(<String, Object?>{
              'freq': 'weekly',
              'interval': 1,
              'weekdays': <int>[1, 3],
              'basis': 'due',
              'anchor': '2026-11-08',
              'until': null,
              'count': null,
              'futureField': true,
            }),
          ),
          steps: Value(
            jsonEncode(<Object?>[
              <String, Object?>{'id': 's1', 'title': 'Shop', 'done': true},
              <String, Object?>{'id': 's2', 'title': 'Pay', 'done': false},
            ]),
          ),
          snoozedUntil: Value(_at(1700007000)),
          linkedDiaryId: const Value('diary-rich'),
          sortOrder: const Value(2.25),
          metadata: Value(
            jsonEncode(<String, Object?>{
              'sourceDiaryId': 'diary-rich',
              'repeatDone': 3,
            }),
          ),
          createdAt: _at(1700006200),
          updatedAt: _at(1700006300),
        ),
      );
  await db
      .into(db.todos)
      .insert(
        TodosCompanion.insert(
          todoId: 'todo-inbox',
          title: 'Done in inbox',
          completedAt: Value(_at(1700006500)),
          // 坏数据：提醒不是 JSON，步骤是对象而不是数组——都原样保留。
          reminders: const Value('not json ['),
          steps: const Value('{"not":"array"}'),
          repeat: const Value('broken {'),
          createdAt: _at(1700006200),
          updatedAt: _at(1700006600),
        ),
      );
}

/// 悬空的待办（清单与日记都不在）：规范化原样保留，由规划器校正。不放进
/// `seedEveryEntity`——那里的数据当作“一台正常设备”，规划器会顺手把悬空
/// 引用修掉，别的测试据此断言写入列表。
Future<void> seedDanglingTodo(AppDatabase db) async {
  await db
      .into(db.todos)
      .insert(
        TodosCompanion.insert(
          todoId: 'todo-dangling',
          // 悬空：清单与日记都不在（规范化原样保留，由规划器校正）。
          listId: const Value('list-gone'),
          linkedDiaryId: const Value('diary-gone'),
          title: 'Dangling',
          sortOrder: const Value(-3),
          createdAt: _at(1700006200),
          updatedAt: _at(1700006200),
        ),
      );
}
