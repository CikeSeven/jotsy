import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_vision.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/http_cancel_token.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_registry.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_agent_image_slots.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_chat_images.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/export_test_images.dart';

/// 智能体看图：read_diaries 在正文的图片位置写“[图片 n]”；view_images 按
/// 同样的编号取任意几张，一次最多“每次最多发送”那么多、其余列出来下次再
/// 要；整次请求满了就不再附图；私密日记不给；也能按 P 编号重看对话里的图。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SettingsService settings;
  late ProviderContainer container;
  late Directory files;

  setUpAll(() async {
    await initializeDateFormatting('zh');
  });

  setUp(() async {
    AiVisionImages.debugClearCache();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
    );
    files = await Directory.systemTemp.createTemp('ai_view_images_');
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    await files.delete(recursive: true);
  });

  final zh = lookupAppLocalizations(const Locale('zh'));

  AiToolContext context({
    AiPreferences prefs = AiPreferences.defaults,
    List<AiChatImage> chatImages = const <AiChatImage>[],
    AiImageBudget? budget,
  }) => AiToolContext(
    container: container,
    l10n: zh,
    kit: AiPromptKit.resolve(prefs: prefs, appLocale: const Locale('zh')),
    env: AiToolEnv(features: AppFeatures.defaults, prefs: prefs, vision: true),
    citations: AiCitationBook(),
    allowance: AiWordAllowance(100000),
    token: HttpCancelToken(),
    chatImages: chatImages,
    imageBudget: budget,
    now: DateTime(2026, 11, 10, 10),
  );

  Future<AiToolOutcome> run(
    String name,
    Map<String, Object?> args,
    AiToolContext with_,
  ) {
    final tool = aiToolByName(name)!;
    return tool.run(
      with_,
      with_.citations.resolveDiaryArgs(
        tool.schema.validate(args),
        tool.diaryIdArgs,
      ),
    );
  }

  /// 一张小 JPEG（原样发送）。
  String photo(String name) {
    final file = File('${files.path}/diary_images/m/$name')
      ..createSync(recursive: true)
      ..writeAsBytesSync(base64Decode(jpgBase64));
    return file.path;
  }

  /// 一篇带文字与 [count] 张图片的日记：文字、图 1、图 2… 交替。
  Future<String> diaryWithPhotos(int count, {String title = '海边'}) {
    final children = <Map<String, Object?>>[
      {
        'type': 'paragraph',
        'data': {
          'delta': [
            {'insert': '傍晚去海边'},
          ],
        },
      },
      for (var i = 1; i <= count; i++)
        {
          'type': 'image',
          'data': {'url': photo('p$i.jpg')},
        },
    ];
    return db.createDiary(
      title: title,
      contentDocJson: jsonEncode({
        'document': {'type': 'page', 'children': children},
      }),
      contentText: '傍晚去海边',
      metadataJson: '{}',
      createdAtOverride: DateTime(2026, 11, 1, 9),
    );
  }

  test('only offered when this turn can send images', () {
    final tool = aiToolByName('view_images')!;
    const env = AiToolEnv(
      features: AppFeatures.defaults,
      prefs: AiPreferences.defaults,
    );
    expect(tool.isAvailable(env), isFalse);
    expect(
      tool.isAvailable(
        const AiToolEnv(
          features: AppFeatures.defaults,
          prefs: AiPreferences.defaults,
          vision: true,
        ),
      ),
      isTrue,
    );
  });

  test('read_diaries marks where each photo is', () async {
    final id = await diaryWithPhotos(2);
    final outcome = await run('read_diaries', {
      'ids': [id],
    }, context());
    final data = outcome.data! as Map;
    final entry = (data['diaries'] as List).single as Map;
    final text = entry['text'] as String;
    expect(text, contains('傍晚去海边'));
    expect(text, contains(zh.aiPromptDiaryImage(1)));
    expect(
      text.indexOf(zh.aiPromptDiaryImage(1)),
      lessThan(text.indexOf(zh.aiPromptDiaryImage(2))),
    );
    expect(entry['photos'], 2);
    expect(data['photos_hint'], contains('view_images'));
  });

  test('picks any photos by number, a few per call', () async {
    final id = await diaryWithPhotos(10);
    final ctx = context(prefs: AiPreferences.decode('{"visionImages":3}'));
    // 第 4、5、6、7 张：只发前 3 张，第 7 张留到下次。
    final outcome = await run('view_images', {
      'diary_id': id,
      'images': [4, 5, 6, 7],
    }, ctx);
    final data = outcome.data! as Map;
    expect(data['attached'], ['D1#4', 'D1#5', 'D1#6']);
    expect(data['not_sent_yet'], ['D1#7']);
    expect(data['entry_photos'], 10);
    expect(outcome.images.map((image) => image.source.split('/').last), [
      'p4.jpg',
      'p5.jpg',
      'p6.jpg',
    ]);
    expect(outcome.images.first.diaryId, id);
    expect(outcome.summary, zh.aiToolViewedImages(3));

    // 按编号（D1）也认，后面那张拿得到。
    final rest = await run('view_images', {
      'diary_id': 'D1',
      'images': [10],
    }, ctx);
    expect((rest.data! as Map)['attached'], ['D1#10']);
  });

  test('numbers that do not exist are reported, not guessed', () async {
    final id = await diaryWithPhotos(2);
    final outcome = await run('view_images', {
      'diary_id': id,
      'images': [2, 9],
    }, context());
    final data = outcome.data! as Map;
    expect(data['attached'], ['D1#2']);
    expect(((data['problems'] as List).single as Map)['image'], 9);
  });

  test('a full request takes no more photos', () async {
    final id = await diaryWithPhotos(3);
    final budget = AiImageBudget(maxCount: 1);
    final outcome = await run('view_images', {
      'diary_id': id,
    }, context(budget: budget));
    final data = outcome.data! as Map;
    expect(data['attached'], ['D1#1']);
    expect(data['not_sent_yet'], ['D1#2', 'D1#3']);
    expect(data['hint'], contains('already carries'));
    expect(budget.count, 1);
  });

  test('private entries are refused', () async {
    final id = await diaryWithPhotos(1);
    final notebook = await db.createNotebook(
      name: '私密',
      visibility: NotebookVisibility.hidden,
    );
    await db.addDiariesToNotebook(notebook, [id]);
    expect(
      () => run('view_images', {'diary_id': id}, context()),
      throwsA(isA<AiToolFailure>()),
    );
  });

  test('chat photos can be looked at again by their number', () async {
    final sea = photo('sea.jpg');
    final images = [
      AiChatImage(ref: 'P1', messageId: 'm1', index: 0, path: sea),
      const AiChatImage(ref: 'P2', messageId: 'm1', index: 1, path: ''),
    ];
    final outcome = await run('view_images', {
      'attachments': ['p1', 'P2', 'P7'],
    }, context(chatImages: images));
    final data = outcome.data! as Map;
    expect(data['attached'], ['P1']);
    expect(
      [
        for (final problem in data['problems'] as List)
          (problem as Map)['attachment'],
      ],
      ['P2', 'P7'],
    );
    expect(outcome.images.single.diaryId, isNull);
  });
}
