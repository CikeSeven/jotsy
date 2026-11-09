// 智能体一轮的请求（纯函数）。
//
// 提示缓存按前缀命中，所以请求从前到后越稳定的东西越靠前：
// - 系统提示词：基础身份 + 智能体说明 + 指南目录 + 人设 + 关于我 + 回答长度
//   + 回答语言（[AiPromptKit.system]，同一段对话里提示词语言固定，见
//   `AiChatController`），工具定义按固定顺序发送；
// - 以前各轮原样回放（`ai_agent_history.dart`），与上一轮最后一次请求逐字
//   相同；
// - 最后是这一轮的问题：现在几点、对话范围、固定的日记（窗口里已经带过就
//   不再重复）与问题本身（[aiAgentPrompt]）。这段全文落库到用户消息的
//   `meta.prompt`，以后各轮原样回放。

import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../models/ai_built_ins.dart';
import '../tools/ai_tool.dart';
import 'ai_agent_history.dart';
import 'ai_prompt_builder.dart';

/// 这一轮问题发给模型的全文：现在几点、对话范围、固定的日记与问题。
String aiAgentPrompt(
  AiPromptKit kit, {
  required String question,
  required DateTime now,
  String? scopeLine,
  String? fixedDiary,
}) {
  final head = <String>[
    kit.l10n.aiPromptAgentNow(
      '${kit.date(now)} '
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}',
    ),
    ?scopeLine,
    ?fixedDiary,
  ];
  return '${head.join('\n\n')}\n\n---\n\n${question.trim()}';
}

AiRequest aiAgentRequest(
  AiPromptKit kit, {
  required AiAgentHistory history,
  required String prompt,
  required AiPersonaInfo persona,
  required List<AiTool> tools,
  String guideIndex = '',
  String? cacheKey,
}) {
  final l10n = kit.l10n;
  final messages = [...history.messages];
  final last = messages.lastOrNull;
  // 上一轮停在工具结果或出错的问题上时，这一轮的问题并进同一条用户消息
  // （客户端照样把工具结果与文字拆开），保持用户 / 助手交替。
  if (last != null && last.role == AiRole.user) {
    messages[messages.length - 1] = AiMessage(AiRole.user, <AiPart>[
      ...last.parts,
      AiTextPart(prompt),
    ]);
  } else {
    messages.add(AiMessage.text(AiRole.user, prompt));
  }
  return AiRequest(
    model: '',
    system: kit.system(
      task: guideIndex.isEmpty
          ? l10n.aiPromptAgentSystem
          : '${l10n.aiPromptAgentSystem}\n\n${l10n.aiPromptAgentGuide(guideIndex)}',
      persona: persona,
      withLength: true,
    ),
    temperature: kit.temperature(AiTaskKind.chat),
    messages: messages,
    tools: [for (final tool in tools) tool.spec],
    cacheKey: cacheKey,
  );
}
