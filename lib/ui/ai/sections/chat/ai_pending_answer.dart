// 正在进行的这一轮（列表末尾）：智能体的步骤与流式文字，或检索问答的状态
// 与流式回答，同落库的回答一样分段（`buildAiAnswerSegments`，live）。调用方
// 用 `ListenableBuilder` 监听 `run` 与 `agentTurn`，流式更新只重建这一项。

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../controllers/ai_chat_controller.dart';
import '../../models/ai_built_ins.dart';
import '../../viewmodels/ai_answer_segments.dart';
import '../../viewmodels/ai_task_prompts.dart';
import '../../widgets/ai_stream_reveal.dart';
import '../ai_chat_message_view.dart';
import 'ai_answer_actions.dart';
import 'ai_answer_segments_view.dart';

/// 为这一轮生成用户可做的事（引用、确认卡）。
typedef AiPendingActionsBuilder =
    AiAnswerActions Function({
      required List<AiCitation> citations,
      void Function(String callId, bool approved)? onDecide,
    });

class AiPendingAnswer extends StatelessWidget {
  const AiPendingAnswer({
    super.key,
    required this.controller,
    required this.persona,
    required this.showReasoning,
    required this.actionsFor,
    this.handoff,
  });

  final AiChatController controller;
  final AiPersonaInfo persona;
  final bool showReasoning;
  final AiPendingActionsBuilder actionsFor;

  /// 正文“放到了哪里”：这一轮落库后由那条回答接着放完。
  final AiRevealHandoff? handoff;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final turn = controller.agentTurn;
    final List<AiAnswerSegment> segments;
    final AiAnswerActions actions;
    final String? status;
    if (controller.phase == AiChatPhase.working && turn != null) {
      segments = buildAiAnswerSegments(
        steps: turn.steps,
        reasoning: turn.reasoning,
        text: turn.text,
        showReasoning: showReasoning,
        thinkingMs: turn.thinking.elapsedMs,
        preparingTool: turn.preparingTool,
        live: true,
      );
      actions = actionsFor(
        citations: turn.toolContext.citations.all,
        onDecide: (callId, approved) => turn.decide(callId, approved: approved),
      );
      status = null;
    } else {
      final run = controller.run;
      segments = buildAiAnswerSegments(
        steps: const [],
        reasoning: run.reasoning,
        text: run.text,
        showReasoning: showReasoning,
        thinkingMs: run.thinking.elapsedMs,
        live: true,
      );
      actions = actionsFor(citations: controller.pendingCitations);
      status = switch (controller.phase) {
        AiChatPhase.planning => l10n.aiChatPlanning,
        AiChatPhase.searching => l10n.aiChatSearching,
        _ => null,
      };
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AiAnswerHeader(persona: persona),
          const SizedBox(height: 10),
          AiAnswerSegmentsView(
            keyPrefix: 'pending',
            segments: segments,
            actions: actions,
            live: true,
            clock: turn?.thinking ?? controller.run.thinking,
            status: status,
            handoff: handoff,
          ),
        ],
      ),
    );
  }
}
