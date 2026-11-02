import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> diary(
    String title, {
    String? body,
    DateTime? at,
    DateTime? unlockAt,
    List<String>? notebookIds,
    List<int> tagIds = const <int>[],
    String metadata = '{}',
  }) {
    final text = body ?? title;
    return db.createDiary(
      title: title,
      contentDocJson: '[{"insert":"$text\\n"}]',
      contentText: text,
      metadataJson: metadata,
      notebookIds: notebookIds,
      tagIds: tagIds,
      createdAtOverride: at ?? DateTime(2026, 3, 10),
      capsuleUnlockAt: unlockAt,
      capsuleLockedAt: unlockAt == null ? null : DateTime(2026, 1, 1),
    );
  }

  Future<Set<String>> titles(Future<List<AiContextDiary>> query) async => {
    for (final row in await query) row.title,
  };

  group('context diaries', () {
    test('never include trash, sealed capsules or private diaries', () async {
      final secret = await db.createNotebook(
        name: 'secret',
        visibility: NotebookVisibility.locked,
      );
      final child = await db.createNotebook(name: 'child', parentId: secret);
      await diary('plain');
      final archived = await diary('archived');
      await db.archiveDiary(archived);
      final trashed = await diary('trashed');
      await db.softDeleteDiary(trashed);
      await diary(
        'sealed',
        unlockAt: DateTime.now().add(const Duration(days: 9)),
      );
      await diary('private', notebookIds: [secret]);
      await diary('inherited', notebookIds: [child]);

      expect(await titles(db.getAiContextDiaries()), {'plain', 'archived'});
      expect(await titles(db.getAiContextDiaries(includeArchived: false)), {
        'plain',
      });
      // 私密本自己的范围会放进私密日记，AI 上下文仍然一篇都不读。
      expect(
        await titles(
          db.getAiContextDiaries(scope: DiaryNotebookScope(notebookId: secret)),
        ),
        isEmpty,
      );
    });

    test('filters by date range, keywords, notebooks and tags', () async {
      final work = await db.createTag(name: 'work', color: 0xFF000000);
      final travel = await db.createNotebook(name: 'travel');
      final sub = await db.createNotebook(name: 'sub', parentId: travel);
      await diary('早', at: DateTime(2026, 1, 5), body: '去海边');
      await diary('中', at: DateTime(2026, 2, 5), body: '看山', tagIds: [work]);
      await diary('晚', at: DateTime(2026, 3, 5), notebookIds: [sub]);
      await diary('末', at: DateTime(2026, 4, 5), notebookIds: [travel]);

      expect(
        await titles(
          db.getAiContextDiaries(
            start: DateTime(2026, 2, 1),
            end: DateTime(2026, 4, 1),
          ),
        ),
        {'中', '晚'},
      );
      expect(await titles(db.getAiContextDiaries(keywords: ['海', '山', ' '])), {
        '早',
        '中',
      });
      // 排除一本日记本时连同它的子本一起排除。
      expect(
        await titles(db.getAiContextDiaries(excludedNotebookIds: {travel})),
        {'早', '中'},
      );
      expect(await titles(db.getAiContextDiaries(excludedTagNames: {'work'})), {
        '早',
        '晚',
        '末',
      });
      expect(await titles(db.getAiContextDiaries(requiredTagIds: [work])), {
        '中',
      });
      final newest = await db.getAiContextDiaries(newestFirst: true, limit: 2);
      expect(newest.map((row) => row.title), ['末', '晚']);
    });

    test('reads mood, weather, location and tag names from metadata', () async {
      final tag = await db.createTag(name: '家', color: 0xFF000000);
      final id = await diary(
        'meta',
        tagIds: [tag],
        metadata:
            '{"context":{"moodEmoji":"😊","weather":"晴","location":"上海"}}',
      );
      final row = (await db.getAiContextDiaries()).single;
      expect(row.diaryId, id);
      expect(row.mood, '😊');
      expect(row.weather, '晴');
      expect(row.location, '上海');
      expect(row.tags, ['家']);
      expect(row.contentJson, isNull);

      final single = await db.getAiDiary(id);
      expect(single!.contentJson, contains('meta'));
      await db.softDeleteDiary(id);
      expect(await db.getAiDiary(id), isNull);
    });
  });

  group('records', () {
    test('messages keep their order and touch the conversation', () async {
      final id = await db.createAiConversation(
        title: 'Q',
        now: DateTime(2026, 1, 1),
      );
      await db.addAiMessage(
        conversationId: id,
        role: AiMessageRole.user,
        content: 'hi',
        now: DateTime(2026, 1, 2),
      );
      final answer = await db.addAiMessage(
        conversationId: id,
        role: AiMessageRole.assistant,
        content: '',
        now: DateTime(2026, 1, 3),
      );
      await db.updateAiMessage(
        answer,
        content: 'hello',
        status: AiMessageStatus.stopped,
      );
      final messages = await db.getAiMessages(id);
      expect(messages.map((m) => m.content), ['hi', 'hello']);
      expect(messages.last.status, AiMessageStatus.stopped);
      final conversation = await db.getAiConversation(id);
      expect(conversation!.updatedAt, DateTime(2026, 1, 3));
    });

    test('deleting a conversation can be undone with its messages', () async {
      final id = await db.createAiConversation(title: 'Q');
      await db.addAiMessage(
        conversationId: id,
        role: AiMessageRole.user,
        content: 'hi',
      );
      final snapshot = await db.deleteAiConversation(id);
      expect(await db.getAiConversation(id), isNull);
      expect(await db.getAiMessages(id), isEmpty);
      await db.restoreAiConversation(snapshot!);
      expect((await db.getAiConversation(id))!.title, 'Q');
      expect(await db.getAiMessages(id), hasLength(1));
    });

    test('search matches titles and message text; pinned come first', () async {
      final a = await db.createAiConversation(
        title: 'about the sea',
        now: DateTime(2026, 1, 1),
      );
      final b = await db.createAiConversation(
        title: 'other',
        now: DateTime(2026, 1, 2),
      );
      await db.addAiMessage(
        conversationId: b,
        role: AiMessageRole.user,
        content: 'sea and 100% sky',
        now: DateTime(2026, 1, 2),
      );
      await db.updateAiConversation(a, pinned: true);
      final all = await db.watchAiConversations().first;
      expect(all.map((c) => c.conversationId), [a, b]);
      final hits = await db.watchAiConversations(query: 'sea').first;
      expect(hits.map((c) => c.conversationId).toSet(), {a, b});
      final percent = await db.watchAiConversations(query: '100%').first;
      expect(percent.map((c) => c.conversationId), [b]);
    });

    test('hard deleting a diary removes its replies but not recaps', () async {
      final id = await diary('a');
      await db.addAiResult(
        kind: AiResultKind.reply,
        diaryId: id,
        content: 'reply',
      );
      await db.addAiResult(kind: AiResultKind.recap, content: 'recap');
      expect(await db.watchAiRepliesForDiary(id).first, hasLength(1));

      await db.softDeleteDiary(id);
      expect(await db.watchAiRepliesForDiary(id).first, hasLength(1));
      await db.hardDeleteDiary(id);
      expect(await db.watchAiRepliesForDiary(id).first, isEmpty);
      expect(await db.watchAiRecaps().first, hasLength(1));
    });

    test('clearing removes every AI record', () async {
      final id = await db.createAiConversation();
      await db.addAiMessage(
        conversationId: id,
        role: AiMessageRole.user,
        content: 'x',
      );
      await db.addAiResult(kind: AiResultKind.recap, content: 'r');
      expect(await db.watchAiRecordCount().first, 2);
      await db.clearAllAiRecords();
      expect(await db.watchAiRecordCount().first, 0);
      expect(await db.select(db.aiMessages).get(), isEmpty);
    });
  });

  group('schema v17 migration', () {
    test('v16 upgrade creates the AI tables and keeps diaries', () async {
      final root = await Directory.systemTemp.createTemp('jotsy_v17_ai');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/v16.sqlite');
      final original = AppDatabase.forTesting(NativeDatabase(file));
      await original.createDiary(
        title: '升级前',
        contentDocJson: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        metadataJson: '{}',
      );
      await original.close();
      final legacy = sqlite3.open(file.path);
      legacy
        ..execute('DROP TABLE ai_messages')
        ..execute('DROP TABLE ai_conversations')
        ..execute('DROP TABLE ai_results')
        ..execute('PRAGMA user_version = 16');
      legacy.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(
          (await migrated.select(migrated.diaries).getSingle()).title,
          '升级前',
        );
        final id = await migrated.createAiConversation(title: 'new');
        expect((await migrated.getAiConversation(id))!.title, 'new');
        final version = await migrated
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), migrated.schemaVersion);
      } finally {
        await migrated.close();
      }
    });
  });
}
