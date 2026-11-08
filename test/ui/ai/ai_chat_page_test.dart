import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/controllers/ai_assistant_entry.dart';
import 'package:node_diary/ui/ai/pages/ai_chat_page.dart';
import 'package:node_diary/ui/ai/pages/ai_recap_page.dart';
import 'package:node_diary/ui/ai/models/ai_conversation_options.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_task_prompts.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_ai.dart';

/// 与日记对话：智能检索先要检索计划、按计划的关键词找日记、流式回答并
/// 落库（引用只记用到的那篇），第一轮后起标题；“继续聊聊”以那条回应开头、
/// 固定在那篇日记上；主页的快捷问题直接开始对话，历史对话可删除。
void main() {
  late AiProviderStore store;
  late List<AiRequest> requests;

  String lastText(AiRequest request) => request.messages.last.text;

  String reply(AiRequest request) {
    final text = lastText(request);
    final l10n = lookupAppLocalizations(const Locale('zh'));
    if (text.contains(aiRetrievalPlanFormat)) {
      return '{"keywords": ["海边"], "from": null, "to": null}';
    }
    if (text.contains(l10n.aiPromptChatTitle)) return '海边的一天';
    return '你在海边走了很久 [D1]。';
  }

  Future<DiaryDraftsHarness> setUpHarness(WidgetTester tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = const Size(600, 1400);
    store = (await tester.runAsync(AiProviderStore.create))!;
    addTearDown(store.dispose);
    requests = <AiRequest>[];
    await h.settings.setAppFeaturesRaw('{"ai":true}');
    // 这里验证检索问答：关掉工具（智能体见 ai_agent_chat_test.dart）。
    await h.settings.setAiPrefsRaw(
      '{"privacy":{"confirm":"firstTime"},"agent":{"enabled":false}}',
    );
    await tester.runAsync(() async {
      await seedFakeAiProvider(store);
      await store.acknowledgeHost(fakeAiProvider.host);
    });
    return h;
  }

  List<Override> overrides() => [
    aiProviderStoreProvider.overrideWith((ref) async => store),
    aiServiceProvider.overrideWith(
      (ref) async => fakeAiService(store, reply: reply, requests: requests),
    ),
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

  Future<void> settleMany(DiaryDraftsHarness h, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await h.settle();
    }
  }

  testWidgets('smart search plans, finds the entry, answers and saves', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    final beach = await seedDiary(h, '周末', '傍晚去海边散步，风很大');
    await seedDiary(h, '上班', '开了一整天的会');
    await h.pump(
      const AiChatPage(initialQuestion: '我上次去海边是什么感觉？'),
      overrides: overrides(),
    );
    await settleMany(h);

    final plan = requests.first;
    expect(lastText(plan), contains('我上次去海边是什么感觉？'));
    final answer = requests.firstWhere(
      (r) => lastText(r).contains(h.l10n.aiPromptChatContextHeader),
    );
    expect(lastText(answer), contains('傍晚去海边散步'));
    expect(lastText(answer), isNot(contains('开了一整天的会')));
    expect(find.textContaining('你在海边走了很久'), findsOneWidget);
    expect(find.text(h.l10n.aiChatCitations(1)), findsOneWidget);

    final conversations = (await tester.runAsync(
      () => h.database.watchAiConversations().first,
    ))!;
    expect(conversations.single.title, '海边的一天');
    final messages = (await tester.runAsync(
      () => h.database.getAiMessages(conversations.single.conversationId),
    ))!;
    expect([for (final m in messages) m.role], ['user', 'assistant']);
    final citations = AiCitation.decodeList(messages.last.citations);
    expect(citations.single.diaryId, beach);
    await h.unmount();
  });

  testWidgets('continuing from a reflection keeps that entry as context', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    final diaryId = await seedDiary(h, '海边', '傍晚去海边散步');
    final resultId = (await tester.runAsync(
      () => h.database.addAiResult(
        kind: AiResultKind.reply,
        diaryId: diaryId,
        content: '听起来很治愈。',
        metaJson: '{"personaName":"倾听者","personaEmoji":"🫶"}',
      ),
    ))!;
    final row = (await tester.runAsync(
      () => h.database.watchAiResult(resultId).first,
    ))!;
    await h.pump(AiChatPage(seedReply: row), overrides: overrides());
    await settleMany(h, 3);
    expect(find.textContaining('听起来很治愈'), findsOneWidget);
    expect(find.text(h.l10n.aiChatAboutEntry('海边')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '为什么会觉得治愈？');
    // 有了文字发送按钮才可点（下一帧）。
    await tester.pump();
    await tester.tap(find.byTooltip(h.l10n.aiPanelSend));
    await settleMany(h);

    // 固定一篇：不做检索计划，只有回答（与起标题无关：已有标题）。
    expect(requests, hasLength(1));
    final roles = [for (final m in requests.single.messages) m.role];
    expect(roles, [AiRole.user, AiRole.assistant, AiRole.user]);
    expect(lastText(requests.single), contains('傍晚去海边散步'));
    await h.unmount();
  });

  testWidgets('the welcome screen starts a chat and the drawer switches', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    await seedDiary(h, '海边', '傍晚去海边散步');
    await h.pump(const AiChatPage(), overrides: overrides());
    await settleMany(h, 3);
    expect(find.text(h.l10n.aiChatWelcomeTitle), findsOneWidget);
    await tester.tap(find.text(h.l10n.aiHubQuickHappy));
    await settleMany(h);
    expect(requests, isNotEmpty);
    expect(find.textContaining('你在海边走了很久'), findsOneWidget);

    // 新对话：回到欢迎页，刚才那段在“最近的对话”里。
    await tester.tap(find.byTooltip(h.l10n.aiChatNewChat));
    await settleMany(h, 3);
    expect(find.text(h.l10n.aiChatWelcomeTitle), findsOneWidget);
    expect(find.text('海边的一天'), findsOneWidget);

    // 历史抽屉里点那段对话：原地换过去。
    await tester.tap(find.byTooltip(h.l10n.aiChatHistory));
    await settleMany(h, 3);
    // 抽屉滑入的动画走完。
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(h.l10n.aiChatGroupToday), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('海边的一天')),
    );
    await settleMany(h, 3);
    expect(find.text(h.l10n.aiChatWelcomeTitle), findsNothing);
    expect(find.textContaining('你在海边走了很久'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('model and thinking choices stay with the conversation', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    await seedDiary(h, '海边', '傍晚去海边散步');
    await h.pump(const AiChatPage(), overrides: overrides());
    await settleMany(h, 3);

    await tester.tap(find.byTooltip(h.l10n.aiChatModelSheetTitle));
    await settleMany(h, 3);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text(h.l10n.aiThinkingHigh));
    await settleMany(h, 2);
    expect(find.text(h.l10n.aiThinkingHighHint), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await settleMany(h, 3);
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(find.byType(TextField).last, '海边怎么样？');
    // 有了文字发送按钮才可点（下一帧）。
    await tester.pump();
    await tester.tap(find.byTooltip(h.l10n.aiPanelSend));
    await settleMany(h);
    final answer = requests.firstWhere(
      (r) => lastText(r).contains(h.l10n.aiPromptChatContextHeader),
    );
    expect(answer.thinking, AiThinkingLevel.high);
    final conversation = (await tester.runAsync(
      () => h.database.watchAiConversations().first,
    ))!.single;
    expect(
      AiConversationOptions.decode(conversation.options).thinking,
      AiThinkingLevel.high,
    );
    // 标题、检索计划这类短请求不带思考。
    expect(requests.first.thinking, AiThinkingLevel.off);

    // 新对话沿用最近那段的选择。
    await tester.tap(find.byTooltip(h.l10n.aiChatNewChat));
    await settleMany(h, 3);
    expect(
      find.textContaining(h.l10n.aiThinkingHigh, findRichText: true),
      findsWidgets,
    );
    await h.unmount();
  });

  testWidgets('the assistant entry opens a new chat, or recaps without chat', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    // 与真实入口一样：AI 可用（服务读出来）之后才出现。
    final host = Consumer(
      builder: (context, ref, _) => ref.watch(aiHubAvailableProvider)
          ? TextButton(
              onPressed: () => openAiAssistant(context, ref),
              child: const Text('open'),
            )
          : const SizedBox.shrink(),
    );
    await h.pump(host, overrides: overrides());
    await settleMany(h, 3);
    await tester.tap(find.text('open'));
    await settleMany(h, 3);
    expect(find.byType(AiChatPage), findsOneWidget);
    expect(find.text(h.l10n.aiChatWelcomeTitle), findsOneWidget);
    await h.unmount();
  });

  testWidgets('with the chat module off the entry opens recaps', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    await h.settings.setAiPrefsRaw(
      '{"privacy":{"confirm":"firstTime"},"off":["chat"]}',
    );
    // 与真实入口一样：AI 可用（服务读出来）之后才出现。
    final host = Consumer(
      builder: (context, ref, _) => ref.watch(aiHubAvailableProvider)
          ? TextButton(
              onPressed: () => openAiAssistant(context, ref),
              child: const Text('open'),
            )
          : const SizedBox.shrink(),
    );
    await h.pump(host, overrides: overrides());
    await settleMany(h, 3);
    await tester.tap(find.text('open'));
    await settleMany(h, 3);
    expect(find.byType(AiChatPage), findsNothing);
    expect(find.byType(AiRecapPage), findsOneWidget);
    await h.unmount();
  });
}
