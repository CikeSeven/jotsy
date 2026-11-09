import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/agent/ai_agent_loop.dart';
import 'package:node_diary/core/services/ai/ai_client_openai.dart';
import 'package:node_diary/core/services/ai/ai_http.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/ai/ai_service.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/http_cancel_token.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/controllers/ai_agent_turn.dart';
import 'package:node_diary/ui/ai/models/ai_agent_steps.dart';
import 'package:node_diary/ui/ai/models/ai_built_ins.dart';
import 'package:node_diary/ui/ai/models/ai_preference_parts.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_registry.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_agent_history.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_agent_prompts.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_task_prompts.dart';
import 'package:node_diary/ui/settings/providers/app_features_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_ai.dart';

/// 智能体的历史原样回放：下一轮请求的开头与上一轮最后一次请求逐字相同
/// （提示缓存整段命中，模型看到的是真实的工具调用而不是一段“做过的操作”
/// 文字）；换了模型时不带协议回放数据；没有结果的调用补错误结果；旧记录
/// 只回放正文；窗口起点只在超出预算时才挪；引用编号整段对话连续。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;
  late AiProviderStore store;
  final zh = lookupAppLocalizations(const Locale('zh'));
  final target = AiResolvedModel(fakeAiProvider, fakeAiProvider.models.single);

  setUpAll(() async {
    await initializeDateFormatting('zh');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    store = await AiProviderStore.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
    );
    await container.read(settingsServiceProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    store.dispose();
  });

  final kit = AiPromptKit.resolve(
    prefs: AiPreferences.defaults,
    appLocale: const Locale('zh'),
  );
  final persona = aiPersonaById(
    zh,
    AiPreferences.defaults,
    null,
    use: AiPersonaUse.chat,
  );
  final tools = aiAvailableTools(
    const AiToolEnv(
      features: AppFeatures.defaults,
      prefs: AiPreferences.defaults,
    ),
  );

  /// 跑完一轮：落库问题（含发出的全文）与回答，返回这一轮发出的请求。
  Future<List<AiRequest>> runTurn(
    String conversationId,
    String question,
    List<List<AiChunk>> script, {
    DateTime? now,
  }) async {
    final history = await db.getAiMessages(conversationId);
    final questionId = await db.addAiMessage(
      conversationId: conversationId,
      role: AiMessageRole.user,
      content: question,
    );
    final prompt = aiAgentPrompt(
      kit,
      question: question,
      now: now ?? DateTime(2026, 11, 9, 10),
    );
    await db.updateAiMessage(
      questionId,
      metaJson: jsonEncode(<String, Object?>{'prompt': prompt}),
    );
    final requests = <AiRequest>[];
    final turn = AiAgentTurn(
      database: db,
      conversationId: conversationId,
      model: target,
      tools: <String, AiTool>{for (final tool in tools) tool.name: tool},
      toolContext: AiToolContext(
        container: container,
        l10n: zh,
        kit: kit,
        env: AiToolEnv(
          features: container.read(appFeaturesProvider),
          prefs: AiPreferences.defaults,
        ),
        citations: AiCitationBook(aiAgentCitationsOf(history)),
        allowance: AiWordAllowance(100000),
        token: HttpCancelToken(),
      ),
    );
    await turn.begin();
    final request = aiAgentRequest(
      kit,
      history: aiAgentHistory(history, l10n: zh, target: target),
      prompt: prompt,
      persona: persona,
      tools: tools,
      cacheKey: conversationId,
    );
    final result = await AiAgentLoop(
      service: scriptedAiService(store, turns: script, requests: requests),
      model: target,
      host: turn,
    ).run(request, HttpCancelToken());
    await turn.complete(result);
    turn.dispose();
    return requests;
  }

  /// 按 Chat 兼容协议编成请求体里的 messages（含系统提示词）。
  List<Object?> wire(AiRequest request, {AiResolvedModel? model}) =>
      OpenAiChatClient((model ?? target).provider, AiHttp()).buildBody(
            AiService.prepareRequest(model ?? target, request),
            stream: true,
          )['messages']!
          as List<Object?>;

  /// 一步“先说一句、调一个工具、带着思考回放数据”的响应。
  List<AiChunk> toolStep(String id, String name, Map<String, Object?> args) =>
      <AiChunk>[
        const AiChunk(text: '我查一下。'),
        AiChunk(
          toolCalls: [
            AiToolCall(
              id: id,
              name: name,
              argumentsRaw: jsonEncode(args),
              arguments: args,
            ),
          ],
          replay: const [
            AiReplayPart(AiProtocol.openAi, {'reasoning_content': '想一想'}),
          ],
          finishReason: AiFinishReason.toolCalls,
        ),
      ];

  test(
    'the next turn starts with exactly what the last request sent',
    () async {
      final conversation = await db.createAiConversation();
      final first = await runTurn(conversation, '我有哪些标签？', [
        toolStep('call_1', 'list_tags', const {}),
        textTurn('你还没有标签。'),
      ]);
      final second = await runTurn(conversation, '那日记本呢？', [
        toolStep('call_2', 'list_notebooks', const {}),
        textTurn('也还没有日记本。'),
      ]);
      final before = wire(first.last);
      final after = wire(second.first);
      expect(after.length, greaterThan(before.length));
      expect(
        jsonEncode(after.sublist(0, before.length)),
        jsonEncode(before),
        reason: 'the cached prefix must be replayed byte for byte',
      );
      // 上一轮的回答紧跟其后，再是这一轮的问题。
      expect(after[before.length], {'role': 'assistant', 'content': '你还没有标签。'});
      expect((after.last as Map)['content'], contains('那日记本呢？'));
      // 回放的是真实的工具调用（带思考回放数据），没有本地拼的操作记录。
      final toolCall =
          before.firstWhere((m) => (m as Map)['tool_calls'] != null) as Map;
      expect(toolCall['reasoning_content'], '想一想');
      expect(toolCall['content'], '我查一下。');
      expect(jsonEncode(after), isNot(contains('做过的操作')));
      // 同一段对话的第三轮仍然以第二轮的最后一次请求为前缀。
      final third = await runTurn(conversation, '好的', [textTurn('嗯。')]);
      final last = wire(second.last);
      expect(
        jsonEncode(wire(third.single).sublist(0, last.length)),
        jsonEncode(last),
      );
    },
  );

  test('another model gets the calls without replay data or odd ids', () async {
    final conversation = await db.createAiConversation();
    await runTurn(conversation, '我有哪些标签？', [
      toolStep('call:1/x', 'list_tags', const {}),
      textTurn('你还没有标签。'),
    ]);
    final other = AiResolvedModel(
      fakeAiProvider.copyWith(id: 'other'),
      fakeAiProvider.models.single,
    );
    final history = aiAgentHistory(
      await db.getAiMessages(conversation),
      l10n: zh,
      target: other,
    );
    final assistant = history.messages[1];
    expect(assistant.parts.whereType<AiReplayPart>(), isEmpty);
    expect(assistant.toolCalls.single.id, 'call_1_x');
    expect(history.messages[2].toolResults.single.callId, 'call_1_x');
  });

  test('calls without a result get an error result; partial text is '
      'dropped', () async {
    final conversation = await db.createAiConversation();
    await db.addAiMessage(
      conversationId: conversation,
      role: AiMessageRole.user,
      content: '整理一下',
    );
    await db.addAiMessage(
      conversationId: conversation,
      role: AiMessageRole.assistant,
      content: '我先……',
      status: AiMessageStatus.stopped,
      metaJson: jsonEncode({
        'agent': true,
        'providerId': fakeAiProvider.id,
        'model': target.model.id,
        'refs': <Object?>[],
      }),
      stepsJson: AiAgentStepRecord.encodeList(const [
        AiAgentStepRecord(
          calls: [
            AiAgentCallRecord(
              id: 'a',
              tool: 'list_tags',
              args: {},
              status: AiToolCallStatus.succeeded,
              result: '[]',
            ),
            AiAgentCallRecord(
              id: 'b',
              tool: 'list_notebooks',
              args: {},
              status: AiToolCallStatus.cancelled,
            ),
          ],
        ),
      ]),
    );
    final history = aiAgentHistory(
      await db.getAiMessages(conversation),
      l10n: zh,
      target: target,
    );
    expect(history.messages.map((m) => m.role), [
      AiRole.user,
      AiRole.assistant,
      AiRole.user,
    ]);
    final results = history.messages.last.toolResults.toList();
    expect(results.first.content, '[]');
    expect(results.first.isError, isFalse);
    expect(results.last.isError, isTrue);
    expect(results.last.content, contains('stopped'));
    expect(
      jsonEncode(history.messages.map((m) => m.text).toList()),
      isNot(contains('我先')),
    );
  });

  test('old answers replay as text without citation numbers; failed ones '
      'are left out', () async {
    final conversation = await db.createAiConversation();
    Future<void> add(
      String role,
      String content, {
      String? status,
      String? meta,
    }) => db.addAiMessage(
      conversationId: conversation,
      role: role,
      content: content,
      status: status ?? AiMessageStatus.done,
      metaJson: meta ?? '{}',
    );
    await add(AiMessageRole.user, '海边');
    await add(AiMessageRole.assistant, '去过海边 [D1]。', meta: '{"agent":true}');
    await add(AiMessageRole.user, '再问');
    await add(AiMessageRole.assistant, '', status: AiMessageStatus.error);
    final history = aiAgentHistory(
      await db.getAiMessages(conversation),
      l10n: zh,
      target: target,
    );
    expect(history.messages.map((m) => m.text), ['海边', '去过海边。', '再问']);
  });

  test('the window start only moves when the budget is exceeded', () {
    const budget = 100;
    final starts = <int>[
      for (var n = 1; n <= 30; n++)
        aiAgentWindowStart(List<int>.filled(n, 15), budget),
    ];
    // 不超出预算时从头开始；每次超出才一次挪到剩下不超过一半。
    expect(starts.take(6), everyElement(0));
    var moves = 0;
    for (var i = 1; i < starts.length; i++) {
      expect(starts[i], greaterThanOrEqualTo(starts[i - 1]));
      if (starts[i] != starts[i - 1]) moves++;
      final kept = (i + 1 - starts[i]) * 15;
      expect(kept, lessThanOrEqualTo(budget));
    }
    // 30 轮里只挪了几次，其余各轮的前缀都与上一轮相同。
    expect(moves, lessThan(8));
  });

  test('citation numbers continue across turns', () {
    final book = AiCitationBook([
      AiCitation(
        ref: 'D1',
        diaryId: 'a',
        title: 'A',
        date: DateTime(2026, 11, 1),
      ),
      AiCitation(
        ref: 'D4',
        diaryId: 'b',
        title: 'B',
        date: DateTime(2026, 11, 2),
      ),
    ]);
    expect(book.length, 0);
    expect(book.refFor('a', title: 'A', date: DateTime(2026)), 'D1');
    expect(book.refFor('c', title: 'C', date: DateTime(2026)), 'D5');
    expect(book.length, 2);
    expect(book.fresh.map((c) => c.ref), ['D5']);
    expect(book.all.map((c) => c.ref), ['D1', 'D4', 'D5']);
  });

  test('a fixed diary already in the window is not sent again', () async {
    final conversation = await db.createAiConversation();
    await db.addAiMessage(
      conversationId: conversation,
      role: AiMessageRole.user,
      content: '聊聊这篇',
      metaJson: jsonEncode({'prompt': '……全文……', 'scopeDiary': 'd1'}),
    );
    final history = aiAgentHistory(
      await db.getAiMessages(conversation),
      l10n: zh,
      target: target,
    );
    expect(history.scopeDiaries, {'d1'});
    expect(history.messages.single.text, '……全文……');
  });
}
