import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/diary_draft_legacy.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.create();
  });

  tearDown(() => database.close());

  Future<void> migrate() =>
      migrateLegacyCreateDraft(database: database, settings: settings);

  test('the old single draft moves into the drafts box', () async {
    final raw = jsonEncode({
      'title': '升级前写了一半',
      'contentDocJson': '[{"insert":"正文\\n"}]',
      'contentText': '正文',
      'moodEmoji': '🙂',
    });
    await settings.setCreateDiaryDraftRaw(raw);

    await migrate();

    final row = (await database.watchDiaryDrafts().first).single;
    expect(row.title, '升级前写了一半');
    expect(row.contentText, '正文');
    // 整份 JSON 原样作为载荷，心情、标签等字段一个不丢。
    expect(row.payload, raw);
    expect(settings.createDiaryDraftRaw, isNull);

    // 再次启动不会重复迁移。
    await migrate();
    expect(await database.countDiaryDrafts(), 1);
  });

  test('a draft with only an image still counts as content', () {
    final draft = parseLegacyCreateDraft(
      jsonEncode({
        'title': '',
        'contentText': '',
        'contentDocJson': jsonEncode([
          {
            'insert': {'image': '/docs/diary_images/media_1/a.jpg'},
          },
          {'insert': '\n'},
        ]),
      }),
    );
    expect(draft, isNotNull);
  });

  test('an empty old draft is cleared without creating a row', () async {
    await settings.setCreateDiaryDraftRaw(
      jsonEncode({'title': '  ', 'contentText': '', 'contentDocJson': ''}),
    );

    await migrate();

    expect(await database.countDiaryDrafts(), 0);
    expect(settings.createDiaryDraftRaw, isNull);
  });

  test('an unreadable old draft is kept for a later attempt', () async {
    await settings.setCreateDiaryDraftRaw('{"title": "cut off');

    await migrate();

    expect(await database.countDiaryDrafts(), 0);
    expect(settings.createDiaryDraftRaw, '{"title": "cut off');
  });
}
