import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/backup_payload.dart';
import 'package:node_diary/core/services/data_archive_service.dart';

import '../../support/backup_test_fixture.dart';

/// AI 记录随完整备份导出与覆盖恢复，合并按业务 id 匹配（对话连同消息），
/// 日记包不带；所属日记不在载荷里的读后回应丢弃。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  late String diaryId;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.seedCurrentData();
    diaryId =
        (await fixture.database.select(fixture.database.diaries).getSingle())
            .diaryId;
  });
  tearDown(() => fixture.dispose());

  AppDatabase db() => fixture.database;

  Future<void> importWith(
    Map<String, Object?> payload,
    BackupImportMode mode,
  ) async {
    final zip = await fixture.writeZip(payload);
    await DataArchiveService.importFromZip(
      database: db(),
      settingsService: fixture.settings,
      zipPath: zip.path,
      mode: mode,
    );
  }

  Future<String> conversationWith(String title, String message) async {
    final id = await db().createAiConversation(title: title);
    await db().addAiMessage(
      conversationId: id,
      role: AiMessageRole.user,
      content: message,
    );
    return id;
  }

  test('a full backup restores conversations, messages and results', () async {
    final conversation = await conversationWith('Q', 'hi');
    await db().addAiResult(
      kind: AiResultKind.reply,
      diaryId: diaryId,
      content: 'reply',
    );
    await db().addAiResult(kind: AiResultKind.recap, content: 'recap');
    final payload = await fixture.capturePayload();

    await db().clearAllAiRecords();
    await conversationWith('after backup', 'later');
    await importWith(payload, BackupImportMode.replaceAll);

    final conversations = await db().watchAiConversations().first;
    expect(conversations.map((c) => c.conversationId), [conversation]);
    expect((await db().getAiMessages(conversation)).single.content, 'hi');
    expect(await db().watchAiRepliesForDiary(diaryId).first, hasLength(1));
    expect(await db().watchAiRecaps().first, hasLength(1));
  });

  test('merging adds new records and keeps local ones', () async {
    final shared = await conversationWith('local title', 'local');
    final payload = await fixture.capturePayload();
    final tables = payload['database'] as Map;
    // 文件里同一次对话被改过，另有一次本机没有的对话。
    (tables['aiConversations'] as List).add(<String, Object?>{
      'id': 99,
      'conversationId': 'c-new',
      'title': 'from file',
      'scope': '{}',
      'pinned': false,
      'createdAt': 0,
      'updatedAt': 0,
    });
    (tables['aiMessages'] as List).add(<String, Object?>{
      'id': 99,
      'messageId': 'm-new',
      'conversationId': 'c-new',
      'role': AiMessageRole.user,
      'content': 'new message',
      'reasoning': '',
      'citations': '[]',
      'meta': '{}',
      'status': AiMessageStatus.done,
      'createdAt': 0,
    });
    ((tables['aiConversations'] as List).first as Map)['title'] = 'file title';

    await importWith(payload, BackupImportMode.merge);
    expect((await db().getAiConversation(shared))!.title, 'local title');
    expect((await db().getAiMessages('c-new')).single.content, 'new message');

    await importWith(payload, BackupImportMode.mergeOverwrite);
    expect((await db().getAiConversation(shared))!.title, 'file title');
    expect(await db().getAiMessages(shared), hasLength(1));
  });

  test('orphan replies and messages are dropped while decoding', () async {
    final payload = await fixture.capturePayload();
    final tables = payload['database'] as Map;
    tables['aiResults'] = <Object?>[
      <String, Object?>{
        'id': 1,
        'resultId': 'r-orphan',
        'kind': AiResultKind.reply,
        'diaryId': 'missing-diary',
        'scope': '{}',
        'title': '',
        'content': 'x',
        'meta': '{}',
        'createdAt': 0,
      },
    ];
    tables['aiMessages'] = <Object?>[
      <String, Object?>{
        'id': 1,
        'messageId': 'm-orphan',
        'conversationId': 'missing',
        'role': AiMessageRole.user,
        'content': 'x',
        'reasoning': '',
        'citations': '[]',
        'meta': '{}',
        'status': AiMessageStatus.done,
        'createdAt': 0,
      },
    ];
    await importWith(payload, BackupImportMode.replaceAll);
    expect(await db().select(db().aiResults).get(), isEmpty);
    expect(await db().select(db().aiMessages).get(), isEmpty);
  });

  test('diary packages never carry AI records', () async {
    await conversationWith('Q', 'hi');
    await db().addAiResult(
      kind: AiResultKind.reply,
      diaryId: diaryId,
      content: 'reply',
    );
    final package = await BackupPayload.captureDiaries(
      database: db(),
      diaryIds: [diaryId],
    );
    final tables = package.json['database'] as Map;
    expect(tables.containsKey('aiConversations'), isFalse);
    expect(tables.containsKey('aiResults'), isFalse);
  });
}
