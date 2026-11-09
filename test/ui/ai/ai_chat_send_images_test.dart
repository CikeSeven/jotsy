import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/ai/ai_service.dart';
import 'package:node_diary/core/services/ai/ai_vision.dart';
import 'package:node_diary/core/services/storage/storage_reference_index.dart';
import 'package:node_diary/core/services/storage/storage_usage_models.dart';
import 'package:node_diary/ui/ai/controllers/ai_chat_controller.dart';
import 'package:node_diary/ui/ai/models/ai_agent_steps.dart';
import 'package:node_diary/ui/ai/models/ai_chat_scope.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_chat_images.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/export_test_images.dart';
import '../../support/fake_ai.dart';

/// 对话里发图片：图片放在提问之前、提问里写着编号；编号写进消息、之后
/// 不变；下一轮原样重发同样的字节；重新生成与编辑重发带着原图；模型
/// 看不到图片时换成占位，只发图片的问题照样能问、标题写“[1 张图片]”。
void main() {
  late AiProviderStore store;
  late List<AiRequest> requests;
  late AiService service;
  late Directory documents;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');

  Future<DiaryDraftsHarness> setUpHarness(
    WidgetTester tester, {
    bool vision = true,
    bool tools = true,
  }) async {
    rootBundle.clear();
    AiVisionImages.debugClearCache();
    // 托管目录指向临时目录：放弃发送时删除附图只删托管目录里的文件。
    documents = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('ai_chat_photo_'),
    ))!;
    addTearDown(() => documents.deleteSync(recursive: true));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      pathProvider,
      (call) async => documents.path,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(pathProvider, null));
    final h = await DiaryDraftsHarness.create(tester);
    store = (await tester.runAsync(AiProviderStore.create))!;
    addTearDown(store.dispose);
    requests = <AiRequest>[];
    await h.settings.setAppFeaturesRaw('{"ai":true}');
    await h.settings.setAiPrefsRaw('{"autoTitle":false}');
    await tester.runAsync(() async {
      await store.saveProvider(
        fakeAiProvider.copyWith(
          models: [
            AiModelConfig(
              id: 'fake-model',
              vision: vision ? null : false,
              tools: tools,
            ),
          ],
        ),
      );
      await store.acknowledgeHost(fakeAiProvider.host);
    });
    return h;
  }

  List<Override> overrides() => [
    aiProviderStoreProvider.overrideWith((ref) async => store),
    aiServiceProvider.overrideWith((ref) async => service),
  ];

  /// 放一张托管图片（小 JPEG，原样发送）。
  Future<String> photo(WidgetTester tester, String name) async {
    final file = File('${documents.path}/diary_images/media_t/$name');
    await tester.runAsync(() async {
      await file.create(recursive: true);
      await file.writeAsBytes(base64Decode(jpgBase64));
    });
    return file.path;
  }

  /// 拿到一个挂在应用里的 context 与 ref，直接驱动对话控制器。
  Future<(BuildContext, WidgetRef)> host(DiaryDraftsHarness h) async {
    late BuildContext context;
    late WidgetRef ref;
    await h.pump(
      Consumer(
        builder: (c, r, _) {
          context = c;
          ref = r;
          return const SizedBox();
        },
      ),
      overrides: overrides(),
    );
    return (context, ref);
  }

  testWidgets('photos keep their numbers and are re-sent byte for byte', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    final sea = await photo(tester, 'sea.jpg');
    service = scriptedAiService(
      store,
      requests: requests,
      turns: [
        textTurn('看到了海'),
        textTurn('还是海'),
        textTurn('重新答'),
        textTurn('改过的问题'),
      ],
    );
    final (context, ref) = await host(h);
    final controller = AiChatController(
      database: h.database,
      scope: const AiChatScope.auto(),
    );
    addTearDown(controller.dispose);

    await tester.runAsync(
      () => controller.send(context, ref, '这是哪里', images: [sea]),
    );
    final first = requests.single.messages.last;
    final sent = first.parts.first as AiImagePart;
    expect(sent.bytes, base64Decode(jpgBase64));
    final prompt = (first.parts.last as AiTextPart).text;
    expect(prompt, contains('这是哪里'));
    expect(prompt, contains(h.l10n.aiPromptAgentImagesAttached('P1')));

    final id = controller.conversationId!;
    var rows = (await tester.runAsync(() => h.database.getAiMessages(id)))!;
    final question = rows.first;
    expect(decodeAiMessageImages(question.images), [sea]);
    expect(aiChatImagesOf(rows, question.messageId).single.ref, 'P1');

    // 下一轮：历史里的那张图原样重发（同样的字节、同样的位置）。
    await tester.runAsync(() => controller.send(context, ref, '再看看'));
    final replayed = requests[1].messages.first;
    expect((replayed.parts.first as AiImagePart).bytes, sent.bytes);
    expect((replayed.parts.last as AiTextPart).text, prompt);

    // 重新生成最后一个回答：问题没有附图，编号照旧。
    await tester.runAsync(() => controller.regenerate(context, ref));
    expect(requests, hasLength(3));

    // 编辑最后一个问题：发给模型的历史里第一张图仍是 P1。
    await tester.runAsync(() => controller.editLast(context, ref, '换个问法'));
    expect(requests, hasLength(4));
    expect(
      (requests[3].messages.first.parts.first as AiImagePart).bytes,
      sent.bytes,
    );
    rows = (await tester.runAsync(() => h.database.getAiMessages(id)))!;
    expect(rows.where((r) => r.role == AiMessageRole.user), hasLength(2));
    expect(aiChatImages(rows).single.ref, 'P1');
  });

  testWidgets('editing a question with photos keeps them and their numbers', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    final sea = await photo(tester, 'sea.jpg');
    final hill = await photo(tester, 'hill.jpg');
    service = scriptedAiService(
      store,
      requests: requests,
      turns: [textTurn('一'), textTurn('二')],
    );
    final (context, ref) = await host(h);
    final controller = AiChatController(
      database: h.database,
      scope: const AiChatScope.auto(),
    );
    addTearDown(controller.dispose);

    await tester.runAsync(
      () => controller.send(context, ref, '看两张', images: [sea, hill]),
    );
    await tester.runAsync(() => controller.editLast(context, ref, '只看第二张'));
    final rows = (await tester.runAsync(
      () => h.database.getAiMessages(controller.conversationId!),
    ))!;
    final question = rows.singleWhere((r) => r.role == AiMessageRole.user);
    expect(question.content, '只看第二张');
    expect(decodeAiMessageImages(question.images), [sea, hill]);
    expect([for (final i in aiChatImages(rows)) i.ref], ['P1', 'P2']);
    final edited = requests.last.messages.last;
    expect(edited.parts.whereType<AiImagePart>(), hasLength(2));
    expect(
      (edited.parts.last as AiTextPart).text,
      contains(h.l10n.aiPromptAgentImagesAttached('P1, P2')),
    );
  });

  testWidgets('the agent looks at an entry photo; it is re-sent next turn', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    final first = await photo(tester, 'p1.jpg');
    final second = await photo(tester, 'p2.jpg');
    final diaryId = (await tester.runAsync(
      () => h.database.createDiary(
        title: '海边',
        contentText: '傍晚',
        metadataJson: '{}',
        contentDocJson: jsonEncode({
          'document': {
            'type': 'page',
            'children': [
              {
                'type': 'image',
                'data': {'url': first},
              },
              {
                'type': 'image',
                'data': {'url': second},
              },
            ],
          },
        }),
      ),
    ))!;
    service = scriptedAiService(
      store,
      requests: requests,
      turns: [
        toolTurn([
          (
            id: 'c1',
            name: 'view_images',
            args: {
              'diary_id': diaryId,
              'images': [2],
            },
          ),
        ]),
        textTurn('第二张是日落'),
        textTurn('记得'),
      ],
    );
    final (context, ref) = await host(h);
    final controller = AiChatController(
      database: h.database,
      scope: const AiChatScope.auto(),
    );
    addTearDown(controller.dispose);

    await tester.runAsync(() => controller.send(context, ref, '看看第二张'));
    // 工具结果在前，看的那张图紧跟其后（同一条用户消息）。
    final results = requests[1].messages.last;
    expect(results.parts.first, isA<AiToolResultPart>());
    expect((results.parts.first as AiToolResultPart).content, contains('D1#2'));
    final viewed = results.parts.last as AiImagePart;
    expect(viewed.bytes, base64Decode(jpgBase64));

    final rows = (await tester.runAsync(
      () => h.database.getAiMessages(controller.conversationId!),
    ))!;
    final call = AiAgentStepRecord.decodeList(
      rows.last.steps,
    ).single.calls.single;
    expect(call.images.single.label, 'D1#2');
    expect(call.images.single.source, second);
    expect(call.images.single.diaryId, diaryId);

    // 下一轮：那一步的结果与图片原样回放，位置、字节都不变。
    await tester.runAsync(() => controller.send(context, ref, '还记得吗'));
    final replayed = requests[2].messages.firstWhere(
      (message) => message.toolResults.isNotEmpty,
    );
    expect(replayed.parts.length, results.parts.length);
    expect((replayed.parts.last as AiImagePart).bytes, viewed.bytes);
  });

  testWidgets('the agent puts a sent photo into a new entry', (tester) async {
    final h = await setUpHarness(tester);
    final sea = await photo(tester, 'sea.jpg');
    service = scriptedAiService(
      store,
      requests: requests,
      turns: [
        toolTurn([
          (
            id: 'c1',
            name: 'create_diary',
            args: const {
              'title': '海边',
              'body': '今天去了海边',
              'images': ['P1'],
            },
          ),
        ]),
        textTurn('写好了'),
      ],
    );
    final (context, ref) = await host(h);
    final controller = AiChatController(
      database: h.database,
      scope: const AiChatScope.auto(),
    );
    addTearDown(controller.dispose);

    await tester.runAsync(
      () => controller.send(context, ref, '把这张图写进日记', images: [sea]),
    );
    final diary = (await tester.runAsync(
      () => (h.database.select(
        h.database.diaries,
      )..where((t) => t.title.equals('海边'))).getSingle(),
    ))!;
    // 日记里的图片块就是消息里的那个托管文件。
    expect(extractDiaryImageSources(diary.content).single, sea);

    // 存储管理同时记着两处引用：删了对话，日记里的图仍在。
    final sources = (await tester.runAsync(
      h.database.getStorageReferenceSources,
    ))!;
    final index = buildStorageReferenceIndex(sources, now: DateTime.now());
    final refs = index.refsOf('diary_images/media_t/sea.jpg');
    expect(refs.whereType<StorageDiaryRef>(), hasLength(1));
    expect(refs.whereType<StorageAiMessageRef>(), hasLength(1));
  });

  testWidgets('a model that cannot see photos gets placeholders instead', (
    tester,
  ) async {
    final h = await setUpHarness(tester, vision: false);
    final sea = await photo(tester, 'sea.jpg');
    service = scriptedAiService(
      store,
      requests: requests,
      turns: [textTurn('收到')],
    );
    final (context, ref) = await host(h);
    final controller = AiChatController(
      database: h.database,
      scope: const AiChatScope.auto(),
    );
    addTearDown(controller.dispose);

    // 只发图片、没有文字。
    await tester.runAsync(
      () => controller.send(context, ref, '', images: [sea]),
    );
    final message = requests.single.messages.last;
    expect(message.hasImages, isFalse);
    expect(
      (message.parts.first as AiTextPart).text,
      h.l10n.aiPromptImageNotSent('P1'),
    );
    // 标题在回答之后另起（不等它）：稍候再读。
    final conversation = (await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return h.database.getAiConversation(controller.conversationId!);
    }))!;
    expect(conversation.title, h.l10n.aiChatImagesSummary(1));
    // 图片照样存下（AI 之后可以把它加进日记）。
    final rows = (await tester.runAsync(
      () => h.database.getAiMessages(controller.conversationId!),
    ))!;
    expect(decodeAiMessageImages(rows.first.images), [sea]);
  });

  testWidgets('without tools a photo-only question is one request', (
    tester,
  ) async {
    final h = await setUpHarness(tester, tools: false);
    final sea = await photo(tester, 'sea.jpg');
    service = scriptedAiService(
      store,
      requests: requests,
      turns: [textTurn('是海')],
    );
    final (context, ref) = await host(h);
    final controller = AiChatController(
      database: h.database,
      scope: const AiChatScope.auto(),
    );
    addTearDown(controller.dispose);

    // 检索问答：没有文字时不再多发一次检索计划，图片放在问题之前。
    await tester.runAsync(
      () => controller.send(context, ref, '', images: [sea]),
    );
    expect(requests, hasLength(1));
    final question = requests.single.messages.last;
    expect(
      (question.parts.first as AiImagePart).bytes,
      base64Decode(jpgBase64),
    );
    expect(question.text, contains(h.l10n.aiChatImagesSummary(1)));
  });

  testWidgets('photos are discarded when the question never gets stored', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    final sea = await photo(tester, 'sea.jpg');
    service = scriptedAiService(store, requests: requests, turns: []);
    final (context, ref) = await host(h);
    final controller = AiChatController(
      database: h.database,
      scope: const AiChatScope.auto(),
    );
    controller.dispose();
    // 控制器已释放：问题写不进库，交过来的图片立即删掉（托管文件没人引用）。
    await tester.runAsync(
      () => controller.send(context, ref, '这是哪里', images: [sea]),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(File(sea).existsSync(), isFalse);
    expect(requests, isEmpty);
  });
}
