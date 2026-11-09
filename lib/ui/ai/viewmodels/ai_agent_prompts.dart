// 智能体一轮的请求（纯函数）。
//
// 提示缓存按前缀命中，所以请求从前到后越稳定的东西越靠前：
// - 系统提示词：基础身份 + 智能体说明 + 指南目录 + 人设 + 关于我 + 回答长度
//   + 回答语言（[AiPromptKit.system]，同一段对话里提示词语言固定，见
//   `AiChatController`），工具定义按固定顺序发送；
// - 以前各轮原样回放（`ai_agent_history.dart`），与上一轮最后一次请求逐字
//   相同；
// - 最后是这一轮的问题：现在几点、对话范围、固定的日记（窗口里已经带过就
//   不再重复）、问题本身与附图的编号（[aiAgentPrompt]）。这段全文落库到
//   用户消息的 `meta.prompt`，以后各轮原样回放；附图（或代替它的占位）放在
//   这段文字之前（[aiAgentRequest] 的 `attachments`），与回放时的位置一致。

import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../models/ai_built_ins.dart';
import '../tools/ai_tool.dart';
import 'ai_agent_history.dart';
import 'ai_prompt_builder.dart';

/// 这一轮问题发给模型的全文：现在几点、对话范围、固定的日记、问题与附图
/// 编号（[imageRefs]，按附图顺序；只有图片时问题为空）。
String aiAgentPrompt(
  AiPromptKit kit, {
  required String question,
  required DateTime now,
  String? scopeLine,
  String? fixedDiary,
  List<String> imageRefs = const <String>[],
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
  final body = <String>[
    if (question.trim().isNotEmpty) question.trim(),
    if (imageRefs.isNotEmpty)
      kit.l10n.aiPromptAgentImagesAttached(imageRefs.join(', ')),
  ];
  return '${head.join('\n\n')}\n\n---\n\n${body.join('\n\n')}';
}

/// [attachments] 是这一轮附图加载成的图片或占位，放在问题文字之前。
AiRequest aiAgentRequest(
  AiPromptKit kit, {
  required AiAgentHistory history,
  required String prompt,
  required AiPersonaInfo persona,
  required List<AiTool> tools,
  List<AiPart> attachments = const <AiPart>[],
  String guideIndex = '',
  String? cacheKey,
}) {
  final l10n = kit.l10n;
  final messages = [...history.messages];
  final last = messages.lastOrNull;
  final question = <AiPart>[...attachments, AiTextPart(prompt)];
  // 上一轮停在工具结果或出错的问题上时，这一轮的问题并进同一条用户消息
  // （客户端照样把工具结果与文字拆开），保持用户 / 助手交替。与历史回放
  // 合并消息的方式一致（`_push`），下一轮回放出的前缀与这次逐字相同。
  if (last != null && last.role == AiRole.user) {
    messages[messages.length - 1] = AiMessage(AiRole.user, <AiPart>[
      ...last.parts,
      ...question,
    ]);
  } else {
    messages.add(AiMessage(AiRole.user, question));
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
    imageOmittedText: l10n.aiPromptImagesRejected,
  );
}
