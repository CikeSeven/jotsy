// 各任务的请求构建（纯函数）：拿 [AiPromptKit] 与这次的材料，返回
// [AiRequest]。模型名由 `AiService` 换成实际模型，这里留空。
//
// 日记一律整篇发送，不设每篇上限；唯一的上限是 AI 隐私里的“最多发送”
// （`AiPrivacyOptions.contextBudget`），超过时才截断（`_budget`）。

import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_prompt_variables.dart';
import 'ai_context_budget.dart';
import 'ai_prompt_builder.dart';

/// 一次请求最多发送的日记字数。
int _budget(AiPromptKit kit) => kit.prefs.privacy.contextBudget;

/// 把要处理的文字包进标签，模型更容易分清“指令”与“材料”。
String _textBlock(String text) => '<text>\n${text.trim()}\n</text>';

/// 写作指令：[action] 为内置或自建指令；[instruction] 为面板里的自由
/// 指令（两者给一个）。
AiRequest aiWritingRequest(
  AiPromptKit kit, {
  AiActionInfo? action,
  String? instruction,
  required String targetText,
  required AiContextDiary diary,
}) {
  final l10n = kit.l10n;
  final String user;
  final template = action?.prompt ?? '';
  final usesVariables = AiPromptVariable.values.any(
    (variable) => aiPromptUses(template, variable),
  );
  if (action != null && usesVariables) {
    final filled = fillAiPromptVariables(template, {
      AiPromptVariable.text: targetText.trim(),
      AiPromptVariable.diary: aiTruncateWords(diary.contentText, _budget(kit)),
      AiPromptVariable.title: diary.title,
      AiPromptVariable.date: kit.date(diary.createdAt),
      AiPromptVariable.mood: diary.mood ?? '',
    });
    user = aiPromptUses(template, AiPromptVariable.text)
        ? filled
        : '$filled\n\n${_textBlock(targetText)}';
  } else if (action != null) {
    user = '${action.prompt.trim()}\n\n${_textBlock(targetText)}';
  } else {
    user =
        '${l10n.aiPromptCustomInstruction(instruction?.trim() ?? '')}\n\n'
        '${_textBlock(targetText)}';
  }
  final title = diary.title.trim();
  return AiRequest(
    model: '',
    system: kit.system(task: l10n.aiPromptWritingSystem, withStyle: true),
    temperature: kit.temperature(AiTaskKind.writing),
    messages: [
      AiMessage.text(
        AiRole.user,
        title.isEmpty ? user : '${l10n.aiPromptFieldTitle}: $title\n\n$user',
      ),
    ],
  );
}

/// 智能填写的 JSON 格式说明（机器格式，不进 ARB）。
const String aiSuggestFormat =
    '{"title": "...", "tags": ["..."], "newTags": ["..."], "mood": "..."}';

/// 智能填写：标题、已有标签、新标签与心情。
AiRequest aiSuggestRequest(
  AiPromptKit kit, {
  required AiContextDiary diary,
  required List<String> tags,
  required List<String> moods,
}) {
  final l10n = kit.l10n;
  final user = <String>[
    l10n.aiPromptSuggestInstruction,
    aiSuggestFormat,
    if (tags.isNotEmpty)
      l10n.aiPromptSuggestTagsList(tags.take(200).join(', ')),
    if (moods.isNotEmpty) l10n.aiPromptSuggestMoodList(moods.join(' ')),
    kit.diary(diary, maxWords: _budget(kit)),
  ].join('\n\n');
  return AiRequest(
    model: '',
    system: kit.system(),
    temperature: kit.temperature(AiTaskKind.suggest),
    maxOutputTokens: 400,
    messages: [AiMessage.text(AiRole.user, user)],
  );
}

/// 描述一张图片（作为日记里的图片说明）。
AiRequest aiDescribeImageRequest(AiPromptKit kit, AiImagePart image) {
  return AiRequest(
    model: '',
    system: kit.system(),
    temperature: kit.temperature(AiTaskKind.vision),
    maxOutputTokens: 300,
    messages: [
      AiMessage(AiRole.user, <AiPart>[
        image,
        AiTextPart(kit.l10n.aiPromptDescribeImage),
      ]),
    ],
  );
}

/// 读后回应：以人设读完一篇日记后回应，可附图片。
AiRequest aiReplyRequest(
  AiPromptKit kit, {
  required AiContextDiary diary,
  required AiPersonaInfo persona,
  List<AiImagePart> images = const <AiImagePart>[],
}) {
  final l10n = kit.l10n;
  final text = <String>[
    l10n.aiPromptReplyInstruction,
    if (images.isNotEmpty) l10n.aiPromptImagesAttached(images.length),
    kit.diary(diary, maxWords: _budget(kit)),
  ].join('\n\n');
  return AiRequest(
    model: '',
    system: kit.system(persona: persona, withLength: true),
    temperature: kit.temperature(AiTaskKind.reply),
    messages: [
      AiMessage(AiRole.user, <AiPart>[...images, AiTextPart(text)]),
    ],
  );
}

/// 写作灵感：今天的日期（含节气等）、可选天气与最近几篇日记（整篇，
/// 合计不超过“最多发送”）。
AiRequest aiPromptsRequest(
  AiPromptKit kit, {
  required String todayLine,
  List<AiContextDiary> recent = const <AiContextDiary>[],
}) {
  final l10n = kit.l10n;
  final parts = <String>[
    l10n.aiPromptPromptsInstruction,
    l10n.aiPromptPromptsToday(todayLine),
    if (recent.isNotEmpty) ...[
      l10n.aiPromptPromptsRecent,
      for (final item in aiBudgetDiaries(recent, budget: _budget(kit)))
        kit.diary(item.diary, maxWords: item.maxWords),
    ],
  ];
  return AiRequest(
    model: '',
    system: kit.system(),
    temperature: kit.temperature(AiTaskKind.prompts),
    maxOutputTokens: 400,
    messages: [AiMessage.text(AiRole.user, parts.join('\n\n'))],
  );
}

/// 把灵感输出拆成问题（每行一个，去掉编号与项目符号）。
List<String> aiParsePrompts(String raw) => [
  for (final line in raw.split('\n'))
    if (line.replaceFirst(RegExp(r'^\s*(?:[-*•]|\d+[.、)])\s*'), '').trim()
        case final question when question.isNotEmpty)
      question,
].take(5).toList();

/// 检索计划的格式说明（机器格式）。
const String aiRetrievalPlanFormat =
    '{"keywords": ["..."], "from": "YYYY-MM-DD or null", '
    '"to": "YYYY-MM-DD or null"}';

/// 对话的检索计划：把问题转成关键词与可能的时间范围。
AiRequest aiRetrievalPlanRequest(
  AiPromptKit kit, {
  required String question,
  required DateTime today,
}) {
  return AiRequest(
    model: '',
    system: kit.system(),
    temperature: kit.temperature(AiTaskKind.utility),
    maxOutputTokens: 300,
    messages: [
      AiMessage.text(
        AiRole.user,
        '${kit.l10n.aiPromptRetrievalPlan(_isoDate(today))}\n'
        '$aiRetrievalPlanFormat\n\n${question.trim()}',
      ),
    ],
  );
}

/// 给一次对话起标题。
AiRequest aiConversationTitleRequest(
  AiPromptKit kit, {
  required String question,
  required String answer,
}) {
  return AiRequest(
    model: '',
    system: kit.system(),
    temperature: kit.temperature(AiTaskKind.utility),
    maxOutputTokens: 60,
    messages: [
      AiMessage.text(
        AiRole.user,
        '${kit.l10n.aiPromptChatTitle}\n\n'
        '${aiTruncateWords(question, 300)}\n\n${aiTruncateWords(answer, 300)}',
      ),
    ],
  );
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// 被引用日记的快照（存进消息的 citations JSON）。
class AiCitation {
  const AiCitation({
    required this.ref,
    required this.diaryId,
    required this.title,
    required this.date,
  });

  /// `D3` 这样的编号。
  final String ref;
  final String diaryId;
  final String title;
  final DateTime date;

  Map<String, Object?> toJson() => <String, Object?>{
    'ref': ref,
    'id': diaryId,
    'title': title,
    'date': date.millisecondsSinceEpoch,
  };

  static AiCitation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final ref = raw['ref'];
    final id = raw['id'];
    final date = raw['date'];
    if (ref is! String || id is! String || date is! int) return null;
    final title = raw['title'];
    return AiCitation(
      ref: ref,
      diaryId: id,
      title: title is String ? title : '',
      date: DateTime.fromMillisecondsSinceEpoch(date),
    );
  }

  static String encodeList(List<AiCitation> citations) =>
      jsonEncode([for (final citation in citations) citation.toJson()]);

  static List<AiCitation> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <AiCitation>[];
      return [
        for (final item in decoded)
          if (AiCitation.fromJson(item) case final citation?) citation,
      ];
    } on FormatException {
      return const <AiCitation>[];
    }
  }
}
