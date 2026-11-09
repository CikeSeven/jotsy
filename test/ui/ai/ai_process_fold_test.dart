import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/controllers/ai_thinking_clock.dart';
import 'package:node_diary/ui/ai/models/ai_agent_steps.dart';
import 'package:node_diary/ui/ai/sections/chat/ai_answer_actions.dart';
import 'package:node_diary/ui/ai/sections/chat/ai_process_fold.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_registry.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_answer_segments.dart';

/// 思考过程折叠块进行中的摘要：还没调用过工具时写“正在思考 · N 秒”；连续
/// 多轮思考 + 调用工具之后写这一块的累计（各轮思考之和、调用个数），不是
/// 最近这一轮的时长；正在执行工具时写那个工具。
void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));

  AiAgentCallRecord call(
    String id, {
    AiToolCallStatus status = AiToolCallStatus.succeeded,
  }) => AiAgentCallRecord(
    id: id,
    tool: 'search_diaries',
    args: const <String, Object?>{},
    status: status,
  );

  Future<void> pump(WidgetTester tester, List<AiAnswerSegment> segments) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AiProcessFold(
            segment: segments.single as AiProcessSegment,
            actions: AiAnswerActions(
              onCitation: (_) {},
              onOpenPage: (_) {},
              onOpenSubject: (_) {},
            ),
            live: true,
            clock: AiThinkingClock(),
          ),
        ),
      ),
    );
  }

  test('a live fold remembers how much of its total is still ticking', () {
    final segments = buildAiAnswerSegments(
      steps: [
        AiAgentStepRecord(thinkingMs: 3000, calls: [call('a')]),
        AiAgentStepRecord(thinkingMs: 4000, calls: [call('b')]),
      ],
      reasoning: '',
      text: '',
      thinkingMs: 2000,
      showReasoning: true,
      live: true,
    );
    final fold = segments.single as AiProcessSegment;
    expect(fold.thinkingMs, 9000);
    expect(fold.liveThinkingMs, 2000);
    expect(fold.toolCount, 2);
  });

  testWidgets('after several rounds the capsule shows the running total', (
    tester,
  ) async {
    await pump(
      tester,
      buildAiAnswerSegments(
        steps: [
          AiAgentStepRecord(thinkingMs: 3000, calls: [call('a')]),
          AiAgentStepRecord(thinkingMs: 4000, calls: [call('b')]),
        ],
        reasoning: '',
        text: '',
        thinkingMs: 2000,
        showReasoning: true,
        live: true,
      ),
    );
    // 3 + 4 + 这一轮的 2 秒，而不是只写这一轮的“正在思考 · 2 秒”。
    final summary =
        '${l10n.aiProcessThoughtFor(9)} · ${l10n.aiProcessTools(2)}';
    expect(find.text(summary, findRichText: true), findsOneWidget);
    expect(
      find.text(l10n.aiProcessThinkingFor(2), findRichText: true),
      findsNothing,
    );
  });

  testWidgets('before any tool call it still says thinking for N seconds', (
    tester,
  ) async {
    await pump(
      tester,
      buildAiAnswerSegments(
        steps: const [],
        reasoning: '',
        text: '',
        thinkingMs: 2000,
        showReasoning: true,
        live: true,
      ),
    );
    expect(
      find.text(l10n.aiProcessThinkingFor(2), findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('while a tool is running the capsule names that tool', (
    tester,
  ) async {
    final running = call('b', status: AiToolCallStatus.executing);
    await pump(
      tester,
      buildAiAnswerSegments(
        steps: [
          AiAgentStepRecord(thinkingMs: 3000, calls: [call('a')]),
          AiAgentStepRecord(thinkingMs: 4000, calls: [running]),
        ],
        reasoning: '',
        text: '',
        showReasoning: true,
        live: true,
      ),
    );
    final label = aiToolByName(
      'search_diaries',
    )!.labelWith(l10n, running.args, running.subjects);
    expect(find.text(label, findRichText: true), findsOneWidget);
  });
}
