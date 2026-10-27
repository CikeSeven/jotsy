import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppExitResponse;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_todo_autosave_controller.dart';

class _DelayedTodoDatabase extends AppDatabase {
  _DelayedTodoDatabase() : super.forTesting(NativeDatabase.memory());

  Completer<void>? firstWrite;
  final written = <String>[];

  @override
  Future<void> updateDiaryContent({
    required String diaryId,
    required String contentDocJson,
    required String contentText,
  }) async {
    written.add(contentDocJson);
    if (written.length == 1) await firstWrite?.future;
    await super.updateDiaryContent(
      diaryId: diaryId,
      contentDocJson: contentDocJson,
      contentText: contentText,
    );
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _DelayedTodoDatabase database;
  late DiaryEditorController document;
  late DiaryTodoAutoSaveController autosave;
  late String id;
  var savedCalls = 0;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    database = _DelayedTodoDatabase();
    document = DiaryEditorController.fromContent(
      jsonEncode({
        'document': {
          'type': 'page',
          'children': [
            {
              'type': 'todo_list',
              'data': {
                'checked': false,
                'delta': [
                  {'insert': 'todo'},
                ],
              },
            },
          ],
        },
      }),
    );
    id = await database.createDiary(
      title: 'Todo',
      contentDocJson: document.contentJson,
      contentText: document.plainText,
      metadataJson: '{}',
    );
    final detail = (await database.getDiaryWithTagsByDiaryId(id))!;
    savedCalls = 0;
    autosave = DiaryTodoAutoSaveController(
      // 刻意保留旧详情，验证订阅尚未刷新时也按实际写入状态判定是否要补存。
      readDetail: () => detail,
      readDocument: () => document.document,
      readDatabase: () => database,
      onSaved: () => savedCalls++,
    );
  });
  tearDown(() async {
    autosave.dispose();
    document.dispose();
    await database.close();
    debugDefaultTargetPlatformOverride = null;
  });

  void check(bool checked) {
    final node = document.document.root.children.single;
    document.apply(
      document.state.transaction..updateNode(node, {'checked': checked}),
    );
    autosave.schedule();
  }

  Future<String> stored() async =>
      (await database.getDiaryWithTagsByDiaryId(id))!.diary.content;

  test(
    'closing a legacy readonly document without ticking never rewrites it',
    () async {
      const legacy = '[{"insert":"todo\\n"}]';
      await database.customStatement(
        'UPDATE diaries SET content = ? WHERE diary_id = ?',
        [legacy, id],
      );
      final detail = (await database.getDiaryWithTagsByDiaryId(id))!;
      final readonly = DiaryTodoAutoSaveController(
        readDetail: () => detail,
        readDocument: () => document.document,
        readDatabase: () => database,
        onSaved: () => fail('reading must not trigger a save'),
      );
      addTearDown(readonly.dispose);
      expect(await binding.handleRequestAppExit(), AppExitResponse.exit);
      expect(await stored(), legacy);
      expect(database.written, isEmpty);
    },
  );

  test(
    'exit saves the last tick and does not write unchanged content twice',
    () async {
      check(true);
      expect(await binding.handleRequestAppExit(), AppExitResponse.exit);
      expect(await stored(), document.contentJson);
      expect(savedCalls, 1);
      expect(await binding.handleRequestAppExit(), AppExitResponse.exit);
      expect(savedCalls, 1);
    },
  );

  test(
    'exit waits for a tick reverted while the first write is running',
    () async {
      database.firstWrite = Completer<void>();
      check(true);
      final saving = autosave.flush();
      expect(database.written, hasLength(1));
      check(false);
      final exiting = binding.handleRequestAppExit();
      database.firstWrite!.complete();
      expect(await saving, isTrue);
      expect(await exiting, AppExitResponse.exit);
      expect(database.written, hasLength(2));
      expect(await stored(), document.contentJson);
    },
  );

  test(
    'save failure cancels exit and a later request retries the tick',
    () async {
      check(true);
      await database.customStatement('PRAGMA query_only = ON');
      expect(await binding.handleRequestAppExit(), AppExitResponse.cancel);
      expect(savedCalls, 0);
      await database.customStatement('PRAGMA query_only = OFF');
      expect(await binding.handleRequestAppExit(), AppExitResponse.exit);
      expect(await stored(), document.contentJson);
    },
  );

  test(
    'disposing during a save writes the newest captured tick after it',
    () async {
      database.firstWrite = Completer<void>();
      check(true);
      final saving = autosave.flush();
      check(false);
      final latest = document.contentJson;
      autosave.dispose();
      database.firstWrite!.complete();
      await saving;
      // dispose 的尾写入不再依赖页面，等已进入队列的数据库事务完成。
      for (
        var attempt = 0;
        attempt < 20 && await stored() != latest;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(await stored(), latest);
      expect(database.written, hasLength(2));
      expect(savedCalls, 0);
    },
  );
}
