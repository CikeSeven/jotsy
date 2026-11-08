import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/ai/ai_service.dart';
import 'package:node_diary/ui/ai/models/ai_agent_steps.dart';
import 'package:node_diary/ui/ai/pages/ai_chat_page.dart';
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
      containsAll(['search_diaries', 'read_diaries', 'open_page']),
    );
    expect(requests.first.messages.last.text, contains('我去过海边吗？'));
    final result = requests.last.messages.last.toolResults.single;
    expect(result.callId, 'c1');
    expect(result.content, contains('傍晚去海边散步'));
    expect(result.content, isNot(contains('开了一整天的会')));

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

    final button = find.text(
      h.l10n.aiAgentOpenPage(h.l10n.settingsTagManagement),
    );
    expect(button, findsOneWidget);
    await tester.tap(button);
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

    expect(find.text(h.l10n.aiConfirmSendAgent), findsOneWidget);
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

    expect(find.text(h.l10n.aiToolListTags), findsOneWidget);
    expect(find.text(h.l10n.aiAgentStepInterrupted), findsOneWidget);
    expect(requests, isEmpty);
    await h.unmount();
  });
}
