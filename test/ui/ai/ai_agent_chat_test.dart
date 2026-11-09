import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/ai/ai_service.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/ui/ai/models/ai_agent_steps.dart';
import 'package:node_diary/ui/ai/pages/ai_chat_page.dart';
import 'package:node_diary/ui/ai/sections/chat/ai_action_cards.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_task_prompts.dart';
import 'package:node_diary/ui/settings/pages/tag_management_page.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_ai.dart';

/// 智能体的对话：模型调工具查日记 → 步骤卡片 → 带引用作答并落库（步骤、
/// 引用）；“前往”按钮打开页面；模型不支持工具时同一个问题改走检索问答；
/// 首次发往某个主机时确认面板说明 AI 会按需读取日记；重开对话时没有结果的
/// 调用显示为“已中断”。
void main() {
  late AiProviderStore store;
  late List<AiRequest> requests;
  late AiService service;

  Future<DiaryDraftsHarness> setUpHarness(
    WidgetTester tester, {
    bool acknowledge = true,
    bool tools = true,
  }) async {
    // 智能体每轮经 rootBundle 读使用指南。rootBundle 缓存的是上一个测试
    // 假异步区里建的 Future，在这个测试里 await 它，回调会排进那个已不再
    // 推进的区，永远不回来；先清掉缓存，让本测试重新读取。
    rootBundle.clear();
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = const Size(600, 1400);
    store = (await tester.runAsync(AiProviderStore.create))!;
    addTearDown(store.dispose);
    requests = <AiRequest>[];
    await h.settings.setAppFeaturesRaw('{"ai":true}');
    await h.settings.setAiPrefsRaw('{"autoTitle":false}');
    await tester.runAsync(() async {
      await store.saveProvider(
        fakeAiProvider.copyWith(
          models: [AiModelConfig(id: 'fake-model', tools: tools)],
        ),
      );
      if (acknowledge) await store.acknowledgeHost(fakeAiProvider.host);
    });
    return h;
  }

  List<Override> overrides() => [
    aiProviderStoreProvider.overrideWith((ref) async => store),
    aiServiceProvider.overrideWith((ref) async => service),
  ];

  Future<String> seedDiary(
    DiaryDraftsHarness h,
    String title,
    String text,
  ) async => (await h.tester.runAsync(
    () => h.database.createDiary(
      title: title,
      contentDocJson: '',
      contentText: text,
      metadataJson: '{}',
    ),
  ))!;

  Future<void> settleMany(DiaryDraftsHarness h, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await h.settle();
    }
  }

  /// 展开思考过程折叠块（摘要胶囊为 Text.rich）。只读与失败的调用折在里面。
  Future<void> expandProcess(DiaryDraftsHarness h, String summary) async {
    final pill = find.textContaining(summary, findRichText: true);
    expect(pill, findsOneWidget);
    await h.tester.tap(pill);
    await settleMany(h, 2);
    await h.tester.pump(const Duration(milliseconds: 400));
  }

  Future<List<AiMessageRow>> savedMessages(DiaryDraftsHarness h) async {
    final conversations = (await h.tester.runAsync(
      () => h.database.watchAiConversations().first,
    ))!;
    return (await h.tester.runAsync(
      () => h.database.getAiMessages(conversations.single.conversationId),
    ))!;
  }

  testWidgets('searches with a tool, shows the step and answers with a '
      'citation', (tester) async {
    final h = await setUpHarness(tester);
    final beach = await seedDiary(h, '周末', '傍晚去海边散步，风很大');
    await seedDiary(h, '上班', '开了一整天的会');
    service = scriptedAiService(
      store,
      requests: requests,
      turns: [
        toolTurn([
          (id: 'c1', name: 'search_diaries', args: const {'query': '海边'}),
        ]),
        textTurn('你在海边散步过 [D1]。'),
      ],
    );
    await h.pump(
      const AiChatPage(initialQuestion: '我去过海边吗？'),
      overrides: overrides(),
    );
    await settleMany(h);

    expect(requests, hasLength(2));
    expect(
      requests.first.tools.map((t) => t.name),
      containsAll([
        'search_diaries',
        'read_diaries',
        'open_page',
        'read_guide',
      ]),
    );
    // 打包的使用指南（中文版）目录在系统提示词里。
    expect(requests.first.system, contains('- cloud-backup: '));
    expect(requests.first.messages.last.text, contains('我去过海边吗？'));
    final result = requests.last.messages.last.toolResults.single;
    expect(result.callId, 'c1');
    expect(result.content, contains('傍晚去海边散步'));
    expect(result.content, isNot(contains('开了一整天的会')));

    // 只读的查找折在“思考过程”里，展开才看得到这一步。
    expect(find.text(h.l10n.aiToolSearchDiariesFor('海边')), findsNothing);
    await expandProcess(h, h.l10n.aiProcessTools(1));
    expect(find.text(h.l10n.aiToolSearchDiariesFor('海边')), findsOneWidget);
    expect(find.text(h.l10n.aiToolFoundEntries(1)), findsOneWidget);
    expect(find.textContaining('你在海边散步过'), findsOneWidget);

    final messages = await savedMessages(h);
    expect([for (final m in messages) m.role], ['user', 'assistant']);
    final answer = messages.last;
    expect(answer.status, AiMessageStatus.done);
    expect(answer.content, '你在海边散步过 [D1]。');
    final steps = AiAgentStepRecord.decodeList(answer.steps);
    expect(steps.single.calls.single.status, AiToolCallStatus.succeeded);
    expect(AiCitation.decodeList(answer.citations).single.diaryId, beach);
    expect((jsonDecode(answer.meta) as Map)['agent'], isTrue);
    await h.unmount();
  });

  testWidgets('reads an entry when the model passes its reference instead '
      'of the id', (tester) async {
    // 实际对话里模型搜索后用 `D1` 调 read_diaries，每篇都回“找不到”，
    // 于是把读不到的正文怪到回收站与时间胶囊头上。
    final h = await setUpHarness(tester);
    final photo = await seedDiary(h, '这样子哦', '123 今天拍了一张晚霞');
    service = scriptedAiService(
      store,
      requests: requests,
      turns: [
        toolTurn([
          (id: 'c1', name: 'search_diaries', args: const {'sort': 'newest'}),
        ]),
        toolTurn([
          (
            id: 'c2',
            name: 'read_diaries',
            args: const {
              'ids': ['D1'],
            },
          ),
        ]),
        textTurn('你拍了晚霞 [D1]。'),
      ],
    );
    await h.pump(
      const AiChatPage(initialQuestion: '这个月我过得怎么样？'),
      overrides: overrides(),
    );
    await settleMany(h);

    expect(requests, hasLength(3));
    final result = requests.last.messages.last.toolResults.single;
    expect(result.callId, 'c2');
    expect(result.isError, isFalse);
    expect(result.content, contains('今天拍了一张晚霞'));
    expect(result.content, isNot(contains('error')));

    final steps = AiAgentStepRecord.decodeList(
      (await savedMessages(h)).last.steps,
    );
    final read = steps[1].calls.single;
    expect(read.status, AiToolCallStatus.succeeded);
    expect(read.summary, h.l10n.aiToolReadEntries(1));
    expect(read.subjects.single.id, photo);
    await h.unmount();
  });

  testWidgets('a notebook card names the notebook and follows renames', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    final notebook = (await tester.runAsync(
      () => h.database.createNotebook(name: '旅行手记'),
    ))!;
    await seedDiary(h, '海边', '傍晚去海边散步');
    final entry = (await tester.runAsync(
      () => h.database.select(h.database.diaries).get(),
    ))!.single.diaryId;
    await tester.runAsync(
      () => h.database.addDiariesToNotebook(notebook, [entry]),
    );
    service = scriptedAiService(
      store,
      requests: requests,
      turns: [
        toolTurn([
          (
            id: 'c1',
            name: 'open_page',
            args: {'destination': 'notebook', 'notebook_id': notebook},
          ),
        ]),
        textTurn('点下面的卡片打开这本。'),
      ],
    );
    await h.pump(
      const AiChatPage(initialQuestion: '打开旅行手记'),
      overrides: overrides(),
    );
    await settleMany(h);

    final card = find.byType(AiDestinationCard);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('旅行手记')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining(h.l10n.aiCardEntries(1)),
      ),
      findsOneWidget,
    );

    await tester.runAsync(
      () => h.database.updateNotebook(notebook, name: '东京之旅'),
    );
    await settleMany(h, 3);
    expect(
      find.descendant(of: card, matching: find.text('东京之旅')),
      findsOneWidget,
    );
    await h.unmount();
  });

  testWidgets('open_page offers a button that opens the page', (tester) async {
    final h = await setUpHarness(tester);
    service = scriptedAiService(
      store,
      requests: requests,
      turns: [
        toolTurn([
          (
            id: 'c1',
            name: 'open_page',
            args: const {'destination': 'settings_tags'},
          ),
        ]),
        textTurn('点下面的按钮去管理标签。'),
      ],
    );
    await h.pump(
      const AiChatPage(initialQuestion: '标签在哪里管理？'),
      overrides: overrides(),
    );
    await settleMany(h);

    // 前往卡片露在外面：标题是页面名，副标题写出在“设置”里，整卡可点。
    final card = find.byType(AiDestinationCard);
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.text(h.l10n.settingsTagManagement),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text(h.l10n.navSettings)),
      findsOneWidget,
    );
    await tester.tap(
      find.byTooltip(h.l10n.aiAgentOpenPage(h.l10n.settingsTagManagement)),
    );
    await settleMany(h);
    expect(find.byType(TagManagementPage), findsOneWidget);
    await h.unmount();
  });

  testWidgets('a model without tool support answers by retrieval', (
    tester,
  ) async {
    final h = await setUpHarness(tester, tools: false);
    await seedDiary(h, '周末', '傍晚去海边散步');
    service = fakeAiService(
      store,
      requests: requests,
      reply: (request) {
        if (request.messages.last.text.contains(aiRetrievalPlanFormat)) {
          return '{"keywords": ["海边"], "from": null, "to": null}';
        }
        return '你去过海边 [D1]。';
      },
    );
    await h.pump(
      const AiChatPage(initialQuestion: '我去过海边吗？'),
      overrides: overrides(),
    );
    await settleMany(h);

    expect(requests, isNotEmpty);
    expect(requests.every((r) => r.tools.isEmpty), isTrue);
    expect(find.textContaining('你去过海边'), findsOneWidget);
    final messages = await savedMessages(h);
    expect(messages.last.steps, '[]');
    await h.unmount();
  });

  testWidgets('the first send to a new host is confirmed and says the AI may '
      'read entries', (tester) async {
    final h = await setUpHarness(tester, acknowledge: false);
    service = scriptedAiService(
      store,
      requests: requests,
      turns: [textTurn('好的。')],
    );
    await h.pump(
      const AiChatPage(initialQuestion: '你好'),
      overrides: overrides(),
    );
    await settleMany(h);

    // 假模型能看图：确认面板说明 AI 还会按需看日记里的图片。
    expect(find.text(h.l10n.aiConfirmSendAgentImages), findsOneWidget);
    expect(requests, isEmpty);
    final send = find
        .widgetWithText(FilledButton, h.l10n.aiConfirmSendAction)
        .last;
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await settleMany(h);
    // 面板收起的动画要走完，确认的结果才交回发送流程。
    await tester.pump(const Duration(seconds: 1));
    await settleMany(h);
    expect(requests, hasLength(1));
    expect(find.text('好的。'), findsOneWidget);
    await h.unmount();
  });

  group('changes', () {
    tearDown(EditingSessionRegistry.instance.debugReset);

    Future<String> trashTurn(DiaryDraftsHarness h, String reply) async {
      final id = await seedDiary(h, '要删的那篇', '正文');
      service = scriptedAiService(
        store,
        requests: requests,
        turns: [
          toolTurn([
            (
              id: 'c1',
              name: 'trash_diaries',
              args: {
                'ids': [id],
              },
            ),
          ]),
          textTurn(reply),
        ],
      );
      return id;
    }

    Future<bool> isDeleted(DiaryDraftsHarness h, String id) async =>
        (await h.tester.runAsync(
          () => h.database.getDiaryWithTagsByDiaryId(id),
        ))!.diary.isDeleted;

    testWidgets('deleting asks first; cancelling tells the model', (
      tester,
    ) async {
      final h = await setUpHarness(tester);
      final id = await trashTurn(h, '好的，没有删。');
      await h.pump(
        const AiChatPage(initialQuestion: '删掉那篇'),
        overrides: overrides(),
      );
      await settleMany(h);

      expect(find.text(h.l10n.aiAgentConfirmDelete), findsOneWidget);
      expect(find.textContaining('要删的那篇'), findsOneWidget);
      expect(requests, hasLength(1));
      await tester.tap(find.text(h.l10n.commonCancel).last);
      await settleMany(h);

      expect(await isDeleted(h, id), isFalse);
      final result = requests.last.messages.last.toolResults.single;
      expect(result.isError, isTrue);
      expect(result.content, contains('declined'));
      expect(find.text(h.l10n.aiAgentStepCancelled), findsOneWidget);
      await h.unmount();
    });

    testWidgets('a confirmed deletion runs and undo brings it back', (
      tester,
    ) async {
      final h = await setUpHarness(tester);
      final id = await trashTurn(h, '已经移入回收站。');
      await h.pump(
        const AiChatPage(initialQuestion: '删掉那篇'),
        overrides: overrides(),
      );
      await settleMany(h);
      await tester.tap(find.text(h.l10n.aiAgentDelete));
      await settleMany(h);
      expect(await isDeleted(h, id), isTrue);
      expect(find.text(h.l10n.aiToolEntriesTrashed(1)), findsOneWidget);

      await tester.tap(find.text(h.l10n.aiAgentUndo));
      await settleMany(h);
      expect(await isDeleted(h, id), isFalse);
      expect(find.text(h.l10n.aiAgentStepUndone), findsOneWidget);
      expect(find.text(h.l10n.aiAgentUndo), findsNothing);
      final steps = AiAgentStepRecord.decodeList(
        (await savedMessages(h)).last.steps,
      );
      expect(steps.single.calls.single.undone, isTrue);
      await h.unmount();
    });

    testWidgets('nothing is written while an editor is open', (tester) async {
      final h = await setUpHarness(tester);
      service = scriptedAiService(
        store,
        requests: requests,
        turns: [
          toolTurn([
            (id: 'c1', name: 'create_diary', args: const {'body': '新的一篇'}),
          ]),
          textTurn('有页面正在编辑。'),
        ],
      );
      EditingSessionRegistry.instance.beginEditing('edit-diary');
      await h.pump(
        const AiChatPage(initialQuestion: '帮我记一篇'),
        overrides: overrides(),
      );
      await settleMany(h);

      final result = requests.last.messages.last.toolResults.single;
      expect(result.isError, isTrue);
      expect(result.content, contains('editing'));
      // 失败的调用折在过程里，摘要标出“未成功”。
      await expandProcess(h, h.l10n.aiProcessFailed(1));
      expect(find.text(h.l10n.aiToolBlockedByEditor), findsOneWidget);
      final diaries = (await tester.runAsync(
        () => h.database.select(h.database.diaries).get(),
      ))!;
      expect(diaries, isEmpty);
      await h.unmount();
    });
  });

  testWidgets('a call without a result shows as interrupted after reopening', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    service = scriptedAiService(store, requests: requests, turns: []);
    final id = (await tester.runAsync(() async {
      final id = await h.database.createAiConversation(title: '旧对话');
      await h.database.addAiMessage(
        conversationId: id,
        role: AiMessageRole.user,
        content: '我有几个标签？',
      );
      await h.database.addAiMessage(
        conversationId: id,
        role: AiMessageRole.assistant,
        content: '',
        status: AiMessageStatus.stopped,
        stepsJson: AiAgentStepRecord.encodeList(const [
          AiAgentStepRecord(
            calls: [
              AiAgentCallRecord(
                id: 'c1',
                tool: 'list_tags',
                args: {},
                status: AiToolCallStatus.executing,
              ),
            ],
          ),
        ]),
      );
      return id;
    }))!;
    await h.pump(AiChatPage(conversationId: id), overrides: overrides());
    await settleMany(h);

    await expandProcess(h, h.l10n.aiProcessTools(1));
    expect(find.text(h.l10n.aiToolListTags), findsOneWidget);
    expect(find.text(h.l10n.aiAgentStepInterrupted), findsOneWidget);
    expect(requests, isEmpty);
    await h.unmount();
  });
}
