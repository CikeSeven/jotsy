import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/ai/models/ai_agent_steps.dart';
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_answer_segments.dart';

/// 回答的分段：思考、过渡句、只读与失败的调用折在一起；前往、改动、确认
/// 卡片与正文露在外面；相邻的折叠项跨步骤合并，相邻的改动合成一组。
void main() {
  AiAgentCallRecord call(
    String id,
    String tool, {
    AiToolCallStatus status = AiToolCallStatus.succeeded,
    AiToolNavigation? navigation,
  }) => AiAgentCallRecord(
    id: id,
    tool: tool,
    args: const {},
    status: status,
    navigation: navigation,
  );

  test('lookups, thinking and remarks fold together across steps', () {
    final segments = buildAiAnswerSegments(
      steps: [
        AiAgentStepRecord(
          reasoning: '先找找',
          thinkingMs: 3000,
          text: '我先查一下。',
          calls: [call('a', 'search_diaries')],
        ),
        AiAgentStepRecord(text: '再读全文。', calls: [call('b', 'read_diaries')]),
      ],
      reasoning: '想好了',
      text: '你去过两次海边。',
      thinkingMs: 2000,
      showReasoning: true,
    );
    expect(segments, hasLength(2));
    final fold = segments.first as AiProcessSegment;
    expect(fold.thinkingMs, 5000);
    expect(fold.toolCount, 2);
    expect(fold.items.map((item) => item.runtimeType).toList(), [
      AiThoughtItem,
      AiNarrationItem,
      AiToolItem,
      AiNarrationItem,
      AiToolItem,
      AiThoughtItem,
    ]);
    expect((segments.last as AiTextSegment).text, '你去过两次海边。');
  });

  test('what the model says before only opening pages is part of the '
      'answer', () {
    const nav = AiToolNavigation(destination: 'settings_notebooks');
    final segments = buildAiAnswerSegments(
      steps: [
        AiAgentStepRecord(text: '我查一下。', calls: [call('a', 'read_guide')]),
        AiAgentStepRecord(
          text: '删除要你自己在管理页完成：点“更多 → 删除”。',
          calls: [call('b', 'open_page', navigation: nav)],
        ),
      ],
      reasoning: '',
      text: '点上面的卡片就到了。',
      showReasoning: true,
    );
    expect(segments.map((s) => s.runtimeType).toList(), [
      AiProcessSegment,
      AiTextSegment,
      AiNavigationSegment,
      AiTextSegment,
    ]);
    final fold = segments.first as AiProcessSegment;
    expect(fold.items.whereType<AiNarrationItem>().single.text, '我查一下。');
    expect((segments[1] as AiTextSegment).text, startsWith('删除要你自己'));
  });

  test('pages and changes stay outside; adjacent changes form a group', () {
    final segments = buildAiAnswerSegments(
      steps: [
        AiAgentStepRecord(
          calls: [
            call('a', 'list_notebooks'),
            call(
              'b',
              'open_page',
              navigation: const AiToolNavigation(destination: 'notebook'),
            ),
            call(
              'c',
              'open_page',
              navigation: const AiToolNavigation(destination: 'settings_tags'),
            ),
            call('d', 'create_todo'),
            call('e', 'complete_todos'),
            call('f', 'search_diaries'),
            call(
              'g',
              'delete_todos',
              status: AiToolCallStatus.awaitingConfirmation,
            ),
          ],
        ),
      ],
      reasoning: '',
      text: '',
      showReasoning: true,
    );
    expect(segments.map((s) => s.runtimeType).toList(), [
      AiProcessSegment,
      AiNavigationSegment,
      AiNavigationSegment,
      AiChangeSegment,
      AiProcessSegment,
      AiConfirmSegment,
    ]);
    expect((segments[3] as AiChangeSegment).calls.map((c) => c.id), ['d', 'e']);
  });

  test('failed calls fold, even changes; hidden thinking still counts', () {
    final segments = buildAiAnswerSegments(
      steps: [
        AiAgentStepRecord(
          reasoning: '秘密的思考',
          thinkingMs: 4000,
          calls: [call('a', 'create_todo', status: AiToolCallStatus.failed)],
        ),
      ],
      reasoning: '',
      text: '没能建好。',
      showReasoning: false,
    );
    final fold = segments.first as AiProcessSegment;
    expect(fold.failedCount, 1);
    expect(fold.thinkingMs, 4000);
    expect(fold.items.whereType<AiThoughtItem>(), isEmpty);
    expect(segments.last, isA<AiTextSegment>());
  });

  test('a live turn without output still has a fold for “thinking”', () {
    final segments = buildAiAnswerSegments(
      steps: const [],
      reasoning: '',
      text: '',
      showReasoning: true,
      live: true,
    );
    expect(segments.single, isA<AiProcessSegment>());

    final preparing = buildAiAnswerSegments(
      steps: const [],
      reasoning: '',
      text: '',
      showReasoning: true,
      preparingTool: 'search_diaries',
      live: true,
    );
    expect(
      (preparing.single as AiProcessSegment).items.single,
      isA<AiPreparingItem>(),
    );
  });

  test('a plain answer has no fold at all', () {
    final segments = buildAiAnswerSegments(
      steps: const [],
      reasoning: '',
      text: '好的。',
      showReasoning: true,
    );
    expect(segments.single, isA<AiTextSegment>());
  });
}
