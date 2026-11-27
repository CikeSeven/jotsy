// 待办助手的请求构建（纯函数）：详情的“AI 拆解”与快速新建的“AI 整理”。
// 提示词文字全部在 ARB（`aiPromptTodo*`）；只有 JSON Lines 的行格式是机器
// 格式，与智能填写的格式说明一样不进 ARB。输出的解析见
// `ui/todos/viewmodels/todo_ai_output.dart`。

import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import 'ai_context_budget.dart';
import 'ai_prompt_builder.dart';

/// “AI 整理”每行的格式（机器格式，不进 ARB）。
const String aiTodoOrganizeFormat =
    '{"title": "...", "date": "YYYY-MM-DD", "time": "HH:mm", '
    '"priority": 0, "list": "...", "tags": ["..."]}';

/// 一次最多告诉模型多少个清单名 / 标签名。
const int _maxNames = 100;

String _textBlock(String text) => '<text>\n${text.trim()}\n</text>';

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

AiRequest _request(AiPromptKit kit, String user, {required int maxTokens}) =>
    AiRequest(
      model: '',
      system: kit.system(task: kit.l10n.aiPromptTodoSystem),
      temperature: kit.temperature(AiTaskKind.todos),
      maxOutputTokens: maxTokens,
      // 要边收边长出预览：思考只会让第一条迟迟不出来。
      thinking: AiThinkingLevel.off,
      messages: [AiMessage.text(AiRole.user, user)],
    );

/// 把一条待办拆成步骤：标题、备注（按“最多发送”截断）与已有的步骤。
AiRequest aiTodoStepsRequest(
  AiPromptKit kit, {
  required String title,
  required String note,
  required List<String> steps,
}) {
  final l10n = kit.l10n;
  final body = aiTruncateWords(note.trim(), kit.prefs.privacy.contextBudget);
  final user = <String>[
    l10n.aiPromptTodoStepsInstruction,
    '${l10n.aiPromptTodoFieldTitle}: ${title.trim()}',
    if (body.isNotEmpty) '${l10n.aiPromptTodoFieldNote}:\n${_textBlock(body)}',
    if (steps.isNotEmpty) l10n.aiPromptTodoExistingSteps(steps.join('\n')),
  ].join('\n\n');
  return _request(kit, user, maxTokens: 600);
}

/// 把一段话整理成多条待办：带上今天（推算“明天”“下周三”）、用户的清单
/// 名与已有的待办标签（不是日记标签），模型只能从中选清单。
AiRequest aiTodoOrganizeRequest(
  AiPromptKit kit, {
  required String text,
  required DateTime today,
  required List<String> lists,
  required List<String> tags,
}) {
  final l10n = kit.l10n;
  final user = <String>[
    l10n.aiPromptTodoOrganizeInstruction,
    aiTodoOrganizeFormat,
    l10n.aiPromptTodoToday('${_isoDate(today)} (${kit.date(today)})'),
    if (lists.isNotEmpty)
      l10n.aiPromptTodoLists(lists.take(_maxNames).join(', ')),
    if (tags.isNotEmpty) l10n.aiPromptTodoTags(tags.take(_maxNames).join(', ')),
    _textBlock(text),
  ].join('\n\n');
  return _request(kit, user, maxTokens: 2000);
}
