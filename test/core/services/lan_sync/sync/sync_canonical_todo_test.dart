import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_support.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_todo.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_hash_cache.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_manifest_builder.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';

import 'sync_test_devices.dart';
import 'sync_test_todo_seed.dart';

/// 待办与清单的规范形式（规格 §2.2 的 todoList / todo 行）：JSON 列解析后
/// 原样搬运（未知字段、坏数据都保留）、REAL 顺序一律为浮点数、跨设备逐字节
/// 一致、哈希缓存只认原始列。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestDevice a;
  late SyncTestDevice b;

  setUp(() async {
    a = await SyncTestDevice.create('a');
    b = await SyncTestDevice.create('b');
    await seedEveryEntity(a);
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  SyncRecord recordOf(List<SyncRecord> records, SyncEntity entity, String id) =>
      records.singleWhere((r) => r.key == SyncKey(entity, id));

  Map<Object?, Object?> mainOf(SyncRecord record) =>
      record.facets[SyncFacet.main]! as Map<Object?, Object?>;

  test('canonical todo keeps every column and unknown JSON fields', () async {
    await seedDanglingTodo(a.db);
    final records = await a.records();
    final full = recordOf(records, SyncEntity.todo, 'todo-full');
    expect(full.facets.keys, <String>[SyncFacet.main]);
    expect(mainOf(full), <String, Object?>{
      'listId': 'list-1',
      'title': 'Buy milk',
      'note': '2 bottles\nskimmed',
      'priority': 2,
      'dueDate': '2026-11-08',
      'dueMinute': 900,
      'reminders': <Object?>[
        <String, Object?>{'kind': 'beforeDue', 'minutes': 15},
        <String, Object?>{'kind': 'onDay', 'days': -1, 'minute': 1200},
        <String, Object?>{'kind': 'futureKind', 'x': 1.5},
      ],
      'repeat': <String, Object?>{
        'freq': 'weekly',
        'interval': 1,
        'weekdays': <int>[1, 3],
        'basis': 'due',
        'anchor': '2026-11-08',
        'until': null,
        'count': null,
        'futureField': true,
      },
      'steps': <Object?>[
        <String, Object?>{'id': 's1', 'title': 'Shop', 'done': true},
        <String, Object?>{'id': 's2', 'title': 'Pay', 'done': false},
      ],
      'completedAt': null,
      'snoozedUntil': 1700007000 * 1000,
      'linkedDiaryId': 'diary-rich',
      'sortOrder': 2.25,
      'metadata': <String, Object?>{
        'sourceDiaryId': 'diary-rich',
        'repeatDone': 3,
      },
      'createdAt': 1700006200 * 1000,
      'updatedAt': 1700006300 * 1000,
    });
    // 待办不存放媒体：不做归一，也不引用媒体键。
    expect(full.mediaKeys, isEmpty);

    final inbox = mainOf(recordOf(records, SyncEntity.todo, 'todo-inbox'));
    expect(inbox['listId'], isNull);
    expect(inbox['completedAt'], 1700006500 * 1000);
    expect(inbox['reminders'], 'not json [');
    expect(inbox['steps'], '{"not":"array"}');
    expect(inbox['repeat'], 'broken {');
    expect(inbox['metadata'], <String, Object?>{});

    final dangling = mainOf(
      recordOf(records, SyncEntity.todo, 'todo-dangling'),
    );
    expect(dangling['listId'], 'list-gone');
    expect(dangling['linkedDiaryId'], 'diary-gone');
    expect(dangling['repeat'], isNull);
    expect(dangling['sortOrder'], isA<double>());
    expect(
      syncCanonicalJson(dangling['sortOrder']),
      '-3.0',
      reason: 'REAL 顺序在规范 JSON 里一律写成浮点数',
    );
  });

  test('canonical todo list keeps metadata and writes sortOrder as a double '
      'even when SQLite stored an integer', () async {
    final records = await a.records();
    expect(
      mainOf(recordOf(records, SyncEntity.todoList, 'list-1')),
      <String, Object?>{
        'name': 'Groceries',
        'colorKey': 'teal',
        'iconKey': 'cart',
        'sortOrder': 1.5,
        'metadata': <String, Object?>{
          'z': 1,
          'futureKey': <String, Object?>{'b': 2, 'a': 1},
        },
        'createdAt': 1700006000 * 1000,
        'updatedAt': 1700006100 * 1000,
      },
    );
    final broken = mainOf(recordOf(records, SyncEntity.todoList, 'list-2'));
    expect(broken['metadata'], 'not json');
    expect(syncCanonicalJson(broken['sortOrder']), '2.0');

    // 原始 SQL 写进去的整数也读成浮点数，规范值不变。
    await a.db.customStatement(
      "UPDATE todo_lists SET sort_order = 2 WHERE list_id = 'list-2'",
    );
    final again = mainOf(
      recordOf(await a.records(), SyncEntity.todoList, 'list-2'),
    );
    expect(syncCanonicalJson(again['sortOrder']), '2.0');
  });

  test('written into another device the JSON columns are canonical and read '
      'back byte-for-byte equal', () async {
    final fromA = <SyncRecord>[
      for (final record in await a.records())
        if (record.key.entity == SyncEntity.todo ||
            record.key.entity == SyncEntity.todoList)
          record,
    ];
    await writeRecordsForTest(b, fromA);
    final fromB = <SyncRecord>[
      for (final record in await b.records())
        if (record.key.entity == SyncEntity.todo ||
            record.key.entity == SyncEntity.todoList)
          record,
    ];
    expect(canonicalByKey(fromB), canonicalByKey(fromA));

    final stored = (await b.db.readSyncRows()).todos.singleWhere(
      (row) => row.todoId == 'todo-full',
    );
    // 解析成功的列按规范 JSON 写回（键排序、紧凑），坏数据原样写回。
    expect(stored.repeat, startsWith('{"anchor":"2026-11-08","basis":"due"'));
    expect(
      stored.steps,
      '[{"done":true,"id":"s1","title":"Shop"},'
      '{"done":false,"id":"s2","title":"Pay"}]',
    );
    final inbox = (await b.db.readSyncRows()).todos.singleWhere(
      (row) => row.todoId == 'todo-inbox',
    );
    expect(inbox.reminders, 'not json [');
    expect(inbox.repeat, 'broken {');
  });

  test('hash cache fingerprints follow every todo column', () async {
    final rows = await a.db.readSyncRows();
    final cold = syncObserveRows(rows);
    final cache = syncHashCacheFromJson(
      jsonDecode(jsonEncode(syncHashCacheToJson(cold.cache))),
    );
    expect(
      cache.keys,
      containsAll(<String>['todo:todo-full', 'todoList:list-1']),
    );
    final warm = syncObserveRows(rows, cache: cache);
    expect(warm.cacheMisses, 0);

    await (a.db.update(a.db.todos)..where((t) => t.todoId.equals('todo-full')))
        .write(const TodosCompanion(sortOrder: Value(2.5)));
    await (a.db.update(a.db.todoLists)..where((t) => t.listId.equals('list-1')))
        .write(const TodoListsCompanion(iconKey: Value('basket')));
    final changed = syncObserveRows(
      await a.db.readSyncRows(),
      cache: warm.cache,
    );
    expect(changed.cacheMisses, 2);
    const key = SyncKey(SyncEntity.todo, 'todo-full');
    expect(
      changed.observation.manifest[key]![SyncFacet.main],
      isNot(cold.observation.manifest[key]![SyncFacet.main]),
    );
  });

  test('restoring columns truncates long titles and rejects empty ones', () {
    SyncRecord todo(String title, Object? sortOrder) =>
        SyncRecord(const SyncKey(SyncEntity.todo, 't'), <String, Object?>{
          SyncFacet.main: <String, Object?>{
            'listId': null,
            'title': title,
            'note': '',
            'priority': 0,
            'dueDate': null,
            'dueMinute': null,
            'reminders': <Object?>[],
            'repeat': null,
            'steps': <Object?>[],
            'completedAt': null,
            'snoozedUntil': null,
            'linkedDiaryId': null,
            'sortOrder': sortOrder,
            'metadata': <String, Object?>{},
            'createdAt': 1000,
            'updatedAt': 2000,
          },
        });

    final long = SyncTodoColumns.fromRecord(todo('x' * 600, 3));
    expect(long.title.length, SyncColumnLimits.todoTitle);
    expect(long.sortOrder, 3.0);
    expect(long.reminders, '[]');
    expect(long.repeat, isNull);
    expect(
      () => SyncTodoColumns.fromRecord(todo('', 0.0)),
      throwsFormatException,
    );
    expect(
      () => SyncTodoColumns.fromRecord(todo('ok', 'first')),
      throwsFormatException,
    );
    expect(
      () => SyncTodoListColumns.fromRecord(todo('ok', 0.0)),
      throwsArgumentError,
    );
  });
}
