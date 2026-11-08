import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/agent/ai_agent_loop.dart';
import 'package:node_diary/core/services/ai/ai_failure.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/http_cancel_token.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_ai.dart';

/// 记录回调的宿主：每个调用按 [results] 回一个结果（默认 `{"ok":true}`）。
class _RecordingHost implements AiAgentHost {
  _RecordingHost({this.onExecute});

  final List<String> executed = <String>[];
  final List<AiAgentStepOutput> outputs = <AiAgentStepOutput>[];
  final List<String> started = <String>[];
  final Future<void> Function(AiToolCall call)? onExecute;

  @override
  void onDelta(int step, AiChunk chunk) {
    if (chunk.toolCallStarted case final start?) started.add(start.name);
  }

  @override
  Future<void> onStepOutput(int step, AiAgentStepOutput output) async =>
      outputs.add(output);

  @override
  Future<AiToolResultPart> execute(int step, AiToolCall call) async {
    executed.add(call.name);
    await onExecute?.call(call);
    return AiToolResultPart(
      callId: call.id,
      name: call.name,
      content: '{"ok":true}',
    );
  }
}

void main() {
  late AiProviderStore store;
  final target = AiResolvedModel(fakeAiProvider, fakeAiProvider.models.single);
  const tool = AiToolSpec(
    name: 'list_tags',
    description: 'List tags.',
    parameters: <String, Object?>{'type': 'object'},
  );
  AiRequest request() => AiRequest(
    model: '',
    tools: const [tool],
    messages: [AiMessage.text(AiRole.user, 'hi')],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = await AiProviderStore.create();
  });
  tearDown(() => store.dispose());

  test('runs tools, sends the results back and ends with the answer', () async {
    final requests = <AiRequest>[];
    final service = scriptedAiService(
      store,
      requests: requests,
      turns: [
        toolTurn([
          (id: 'c1', name: 'list_tags', args: const {}),
          (id: 'c2', name: 'search_diaries', args: const {'query': 'sea'}),
        ], text: 'Let me look.'),
        textTurn('Done [D1].'),
      ],
    );
    final host = _RecordingHost();
    final result = await AiAgentLoop(
      service: service,
      model: target,
      host: host,
    ).run(request(), HttpCancelToken());

    expect(result.end, AiAgentEnd.answered);
    expect(result.text, 'Done [D1].');
    expect(result.steps, 1);
    expect(result.usage?.outputTokens, 5);
    // 同一步的两个调用按顺序串行执行。
    expect(host.executed, ['list_tags', 'search_diaries']);
    expect(host.started, ['list_tags', 'search_diaries']);
    expect(host.outputs.single.text, 'Let me look.');

    expect(requests, hasLength(2));
    final followUp = requests.last.messages;
    expect(followUp, hasLength(3));
    expect(followUp[1].role, AiRole.assistant);
    expect(followUp[1].text, 'Let me look.');
    expect(followUp[1].toolCalls.map((c) => c.id), ['c1', 'c2']);
    expect(followUp[2].role, AiRole.user);
    expect(followUp[2].toolResults.map((r) => r.callId), ['c1', 'c2']);
    expect(requests.last.tools.single.name, 'list_tags');
  });

  test('the last step forbids tools; ignoring that ends the turn', () async {
    final requests = <AiRequest>[];
    final call = (id: 'c', name: 'list_tags', args: const <String, Object?>{});
    final service = scriptedAiService(
      store,
      requests: requests,
      turns: [
        toolTurn([call]),
        toolTurn([call]),
      ],
    );
    final host = _RecordingHost();
    final result = await AiAgentLoop(
      service: service,
      model: target,
      host: host,
      maxSteps: 2,
    ).run(request(), HttpCancelToken());

    expect(requests.first.toolChoice, AiToolChoice.auto);
    expect(requests.last.toolChoice, AiToolChoice.none);
    expect(result.end, AiAgentEnd.stepsExhausted);
    expect(host.executed, ['list_tags']);
  });

  test('calls from a response that did not finish are never run', () async {
    final service = scriptedAiService(
      store,
      turns: [
        [
          const AiChunk(text: 'partial'),
          const AiChunk(
            toolCalls: [
              AiToolCall(
                id: 'c',
                name: 'list_tags',
                argumentsRaw: '{}',
                arguments: <String, Object?>{},
              ),
            ],
          ),
          // 没有结束原因：流中断了。
        ],
      ],
    );
    final host = _RecordingHost();
    final result = await AiAgentLoop(
      service: service,
      model: target,
      host: host,
    ).run(request(), HttpCancelToken());
    expect(result.end, AiAgentEnd.incomplete);
    expect(result.text, 'partial');
    expect(host.executed, isEmpty);
    expect(host.outputs, isEmpty);
  });

  test(
    'stopping during a tool stops the loop before the next request',
    () async {
      final requests = <AiRequest>[];
      final token = HttpCancelToken();
      final service = scriptedAiService(
        store,
        requests: requests,
        turns: [
          toolTurn([
            (id: 'a', name: 'list_tags', args: const {}),
            (id: 'b', name: 'list_tags', args: const {}),
          ]),
          textTurn('never'),
        ],
      );
      final host = _RecordingHost(onExecute: (call) async => token.cancel());
      await expectLater(
        AiAgentLoop(
          service: service,
          model: target,
          host: host,
        ).run(request(), token),
        throwsA(
          isA<AiException>().having(
            (e) => e.kind,
            'kind',
            AiFailureKind.cancelled,
          ),
        ),
      );
      // 第一个调用之后就停了：第二个不再派发，也不再请求模型。
      expect(host.executed, ['list_tags']);
      expect(requests, hasLength(1));
    },
  );
}
