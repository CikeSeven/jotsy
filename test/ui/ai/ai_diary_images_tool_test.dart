import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/http_cancel_token.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_registry.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_chat_images.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 把对话里的图片加进日记：create_diary / append_to_diary 的 `images`
/// 写成正文的图片块（与消息共用同一个托管文件），编号不对时什么都不写，
/// 撤销照常。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SettingsService settings;
  late ProviderContainer container;

  setUpAll(() async {
    await initializeDateFormatting('zh');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  final zh = lookupAppLocalizations(const Locale('zh'));
  const sea = '/data/diary_images/media_a/sea.jpg';
  const hill = '/data/diary_images/media_a/hill.jpg';
  const chat = <AiChatImage>[
    AiChatImage(ref: 'P1', messageId: 'm', index: 0, path: sea),
    AiChatImage(ref: 'P2', messageId: 'm', index: 1, path: hill),
  ];

  AiToolContext context() => AiToolContext(
    container: container,
    l10n: zh,
    kit: AiPromptKit.resolve(
      prefs: AiPreferences.defaults,
      appLocale: const Locale('zh'),
    ),
    env: const AiToolEnv(
      features: AppFeatures.defaults,
      prefs: AiPreferences.defaults,
    ),
    citations: AiCitationBook(),
    allowance: AiWordAllowance(100000),
    token: HttpCancelToken(),
    chatImages: chat,
    now: DateTime(2026, 11, 10, 10),
  );

  Future<AiToolOutcome> run(String name, Map<String, Object?> args) {
    final tool = aiToolByName(name)!;
    final ctx = context();
    return tool.run(
      ctx,
      ctx.citations.resolveDiaryArgs(
        tool.schema.validate(args),
        tool.diaryIdArgs,
      ),
    );
  }

  Future<List<String>> imagesOf(String diaryId) async {
    final diary = (await db.getDiaryWithTagsByDiaryId(diaryId))!.diary;
    return extractDiaryImageSources(diary.content).toList();
  }

  test('a new entry gets the chat photos as image blocks', () async {
    final outcome = await run('create_diary', {
      'title': '海边',
      'body': '今天去了海边\n\n![](P2)',
      'images': ['P1'],
    });
    final id = (outcome.data! as Map)['id'] as String;
    // 正文里放的在原位，images 里的接在最后；路径就是消息里的那个文件。
    expect(await imagesOf(id), [hill, sea]);

    // 撤销把新日记移进回收站（与 create_diary 一贯的撤销口径）。
    await aiToolByName('create_diary')!.undo(container, outcome.undo!);
    expect((await db.getDiaryWithTagsByDiaryId(id))!.diary.isDeleted, isTrue);
  });

  test('photos alone can start an entry', () async {
    final outcome = await run('create_diary', {
      'body': '',
      'images': ['P1'],
    });
    expect(await imagesOf((outcome.data! as Map)['id'] as String), [sea]);
  });

  test('an empty entry without photos is refused', () async {
    expect(
      () => run('create_diary', {'body': '  '}),
      throwsA(isA<AiToolFailure>()),
    );
  });

  test('a wrong photo number writes nothing', () async {
    final before = await db.select(db.diaries).get();
    expect(
      () => run('create_diary', {
        'body': '文字',
        'images': ['P1', 'P9'],
      }),
      throwsA(
        isA<AiToolFailure>().having(
          (e) => e.message,
          'message',
          contains('P9'),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(await db.select(db.diaries).get(), hasLength(before.length));
  });

  test('photos can be appended to an entry and undone', () async {
    final id = await db.createDiary(
      title: '旧',
      contentDocJson: '',
      contentText: '原来的',
      metadataJson: '{}',
    );
    final outcome = await run('append_to_diary', {
      'id': id,
      'text': '',
      'images': ['P2', 'P1'],
    });
    expect(await imagesOf(id), [hill, sea]);

    await aiToolByName('append_to_diary')!.undo(container, outcome.undo!);
    expect(await imagesOf(id), isEmpty);
    expect((await db.getDiaryWithTagsByDiaryId(id))!.diary.contentText, '原来的');
  });
}
