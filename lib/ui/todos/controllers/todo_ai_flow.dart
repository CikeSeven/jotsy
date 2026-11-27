// 待办助手的流程编排（详情的“AI 拆解”、快速新建的“AI 整理”）。
//
// 顺序与写作助手一致：解析模型（没有可用模型时提示）→ 按隐私设置确认 →
// 构建提示词 → 交给 [TodoAiDrafts] 流式生成。确认被取消或解析失败时不发
// 任何请求；每次 await 之后检查 context.mounted（面板可能已经关掉）。写库
// 不在这里：用户在预览里确认后才由调用方一次写入。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/text_stats.dart';
import '../../ai/controllers/ai_privacy_gate.dart';
import '../../ai/providers/ai_providers.dart';
import '../../ai/viewmodels/ai_prompt_builder.dart';
import '../../ai/viewmodels/ai_todo_prompts.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../viewmodels/todo_ai_output.dart';
import 'todo_ai_drafts.dart';

/// 把 [row] 拆成步骤（[steps] 为已有的，不重复）。
Future<void> startTodoAiBreakdown(
  BuildContext context,
  WidgetRef ref,
  TodoAiDrafts<String> drafts, {
  required TodoRow row,
  required List<TodoStep> steps,
}) async {
  final existing = <String>[for (final step in steps) step.title];
  await _start(
    context,
    ref,
    drafts,
    words:
        TextStats.countWords(row.title) +
        TextStats.countWords(row.note) +
        TextStats.countWords(existing.join('\n')),
    sample: '${row.title}\n${row.note}',
    build: (AiPromptKit kit) => aiTodoStepsRequest(
      kit,
      title: row.title,
      note: row.note,
      steps: existing,
    ),
  );
}

/// 把快速新建里的一段话 [text] 整理成多条待办。
Future<void> startTodoAiOrganize(
  BuildContext context,
  WidgetRef ref,
  TodoAiDrafts<TodoAiItem> drafts, {
  required String text,
  required DateTime today,
  required List<TodoListRow> lists,
  required List<String> tags,
}) async {
  await _start(
    context,
    ref,
    drafts,
    words: TextStats.countWords(text),
    sample: text,
    build: (AiPromptKit kit) => aiTodoOrganizeRequest(
      kit,
      text: text,
      today: today,
      lists: <String>[for (final list in lists) list.name],
      tags: tags,
    ),
  );
}

Future<void> _start<T>(
  BuildContext context,
  WidgetRef ref,
  TodoAiDrafts<T> drafts, {
  required int words,
  required String sample,
  required AiRequest Function(AiPromptKit kit) build,
}) async {
  final l10n = context.l10n;
  final AiService service = await ref.read(aiServiceProvider.future);
  if (!context.mounted) return;
  final model = service.resolve(AiTaskKind.todos);
  if (model == null) {
    _hint(context, l10n.aiErrorNotConfigured);
    return;
  }
  final ok = await confirmAiSend(
    context,
    ref,
    model: model,
    summary: AiSendSummary(words: words),
  );
  if (!ok || !context.mounted) return;
  final kit = AiPromptKit.resolve(
    prefs: ref.read(aiPreferencesProvider),
    appLocale: Localizations.localeOf(context),
    sample: sample,
  );
  final request = build(kit);
  await drafts.start(
    (token) => service.stream(model, request, cancelToken: token),
  );
}

void _hint(BuildContext context, String message) {
  unawaited(
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(message)),
    ),
  );
}
