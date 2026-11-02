// 与日记对话的请求（纯函数）。
//
// 每一轮只把这一轮检索到的日记放进最后一条用户消息（编号每轮从 D1 重新
// 开始）；之前的问答作为对话历史原样带上，但去掉其中的引用编号（旧编号指
// 的是上一轮的材料，留着会让模型张冠李戴）。历史只带最近 [kAiChatHistory]
// 条，每条截到 1500 字。
//
// 各家协议对消息顺序的要求不同（Anthropic 要求用户 / 助手交替、以用户
// 开头）：出错的回答不进历史，相邻同一角色的消息合并，开头是助手（预览页
// “继续聊聊”带进来的那条回应）时在前面补上“请回应这篇日记”。

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../models/ai_built_ins.dart';
import 'ai_citations.dart';
import 'ai_context_budget.dart';
import 'ai_prompt_builder.dart';

/// 对话历史最多带几条消息。
const int kAiChatHistory = 12;

/// 一轮对话的请求。[history] 为之前的消息（旧 → 新，不含这一轮的问题）。
AiRequest aiChatRequest(
  AiPromptKit kit, {
  required List<AiMessageRow> history,
  required String question,
  required List<AiBudgetedDiary> diaries,
  required DateTime today,
  required AiPersonaInfo persona,
}) {
  final l10n = kit.l10n;
  final messages = <AiMessage>[];
  void push(AiRole role, String text) {
    if (text.trim().isEmpty) return;
    if (messages.isNotEmpty && messages.last.role == role) {
      final previous = messages.removeLast();
      final merged = [
        for (final part in previous.parts)
          if (part is AiTextPart) part.text,
        text,
      ].join('\n\n');
      messages.add(AiMessage.text(role, merged));
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
    push(
      assistant ? AiRole.assistant : AiRole.user,
      aiTruncateWords(
        assistant ? aiStripCitations(row.content) : row.content,
        1500,
      ),
    );
  }
  final context = diaries.isEmpty
      ? l10n.aiPromptChatNoDiaries
      : [
          l10n.aiPromptChatContextHeader,
          for (final item in diaries)
            kit.diary(item.diary, ref: item.marker, maxWords: item.maxWords),
        ].join('\n\n---\n\n');
  push(
    AiRole.user,
    '${l10n.aiPromptChatToday(kit.date(today))}\n\n$context\n\n---\n\n'
    '${question.trim()}',
  );
  return AiRequest(
    model: '',
    system: kit.system(
      task: l10n.aiPromptChatSystem,
      persona: persona,
      withLength: true,
    ),
    temperature: kit.temperature(AiTaskKind.chat),
    messages: messages,
  );
}
