// 智能体一轮的请求（纯函数）。
//
// - 系统提示词是稳定前缀：基础身份 + 智能体说明 + 人设 + 关于我 + 回答
//   长度 + 回答语言（[AiPromptKit.system]），工具定义也按固定顺序发送，
//   利于服务商的提示缓存；会变的东西（现在几点、这次对话的范围）放进最后
//   一条用户消息的开头；
// - 历史只带以前各轮的问题与最终回答（去掉旧编号，截到 1500 字），回答后面
//   附一行本地生成的“这一轮做过的操作”（只列改动与跳转，不列查询）。不
//   回放旧轮的工具消息与签名：换模型、换协议都不会出错，也省 token，需要
//   细节时模型重新查；
// - 出错的回答不进历史，相邻同一角色合并，开头是助手时补一句“请回应这篇
//   日记”（与“与日记对话”同一口径）。

import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../models/ai_agent_steps.dart';
import '../models/ai_built_ins.dart';
import '../tools/ai_tool.dart';
import '../tools/ai_tool_registry.dart';
import 'ai_chat_prompts.dart';
import 'ai_citations.dart';
import 'ai_context_budget.dart';
import 'ai_prompt_builder.dart';

AiRequest aiAgentRequest(
  AiPromptKit kit, {
  required List<AiMessageRow> history,
  required String question,
  required DateTime now,
  required AiPersonaInfo persona,
  required List<AiTool> tools,
  String? scopeLine,
  String? fixedDiary,
}) {
  final l10n = kit.l10n;
  final messages = <AiMessage>[];
  void push(AiRole role, String text) {
    if (text.trim().isEmpty) return;
    if (messages.isNotEmpty && messages.last.role == role) {
      final previous = messages.removeLast();
      messages.add(AiMessage.text(role, '${previous.text}\n\n$text'));
      return;
    }
    messages.add(AiMessage.text(role, text));
  }

  final usable = [
    for (final row in history)
      if (row.status != AiMessageStatus.error && row.content.trim().isNotEmpty)
        row,
  ];
  final recent = usable.length > kAiChatHistory
      ? usable.sublist(usable.length - kAiChatHistory)
      : usable;
  for (final row in recent) {
    final assistant = row.role == AiMessageRole.assistant;
    if (assistant && messages.isEmpty) {
      push(AiRole.user, l10n.aiPromptReplyInstruction);
    }
    if (!assistant) {
      push(AiRole.user, aiTruncateWords(row.content, 1500));
      continue;
    }
    final answer = aiTruncateWords(aiStripCitations(row.content), 1500);
    final actions = aiAgentActionLines(AiAgentStepRecord.decodeList(row.steps));
    push(
      AiRole.assistant,
      actions.isEmpty
          ? answer
          : '$answer\n\n${l10n.aiPromptAgentActionsDone(actions.join('\n'))}',
    );
  }
  final head = <String>[
    l10n.aiPromptAgentNow(
      '${kit.date(now)} '
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}',
    ),
    ?scopeLine,
    ?fixedDiary,
  ];
  push(AiRole.user, '${head.join('\n\n')}\n\n---\n\n${question.trim()}');
  return AiRequest(
    model: '',
    system: kit.system(
      task: l10n.aiPromptAgentSystem,
      persona: persona,
      withLength: true,
    ),
    temperature: kit.temperature(AiTaskKind.chat),
    messages: messages,
    tools: [for (final tool in tools) tool.spec],
  );
}

/// 以前一轮做过的改动与跳转（给模型看的一行一项：工具名 + 参数）。查询类
/// 不列：结果早已过时，需要时模型会重新查。
List<String> aiAgentActionLines(List<AiAgentStepRecord> steps) => [
  for (final step in steps)
    for (final call in step.calls)
      if (call.status == AiToolCallStatus.succeeded &&
          (aiToolByName(call.tool)?.effect ?? AiToolEffect.read) !=
              AiToolEffect.read)
        '- ${call.tool} ${jsonEncode(call.args)}',
];
