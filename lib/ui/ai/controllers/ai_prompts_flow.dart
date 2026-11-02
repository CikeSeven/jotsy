// 写作灵感：让 AI 为今天的日记想几个问题。
//
// 材料：日期（中文提示词另加农历与节气）、可选的天气，以及（用户打开了
// “参考最近的日记”时）最近 3 篇非私密日记的摘录。只在用户点了之后才请求。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/text_stats.dart';
import '../../calendar/viewmodels/calendar_lunar_day.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../providers/ai_providers.dart';
import '../viewmodels/ai_labels.dart';
import '../viewmodels/ai_prompt_builder.dart';
import '../viewmodels/ai_task_prompts.dart';
import 'ai_privacy_gate.dart';

/// 生成写作灵感；取消、失败或没有可用模型时返回 null（失败已提示）。
Future<List<String>?> requestAiPrompts(
  BuildContext context,
  WidgetRef ref, {
  required DateTime date,
  String? weather,
}) async {
  final l10n = context.l10n;
  final prefs = ref.read(aiPreferencesProvider);
  final service = await ref.read(aiServiceProvider.future);
  if (!context.mounted) return null;
  final model = service.resolve(AiTaskKind.prompts);
  if (model == null) {
    _hint(context, l10n.aiErrorNotConfigured);
    return null;
  }
  var recent = const <AiContextDiary>[];
  if (prefs.promptsUseRecent) {
    recent = await ref
        .read(appDatabaseProvider)
        .getAiContextDiaries(
          newestFirst: true,
          limit: 3,
          excludedNotebookIds: prefs.privacy.excludedNotebookIds,
          excludedTagNames: prefs.privacy.excludedTagNames,
          includeArchived: prefs.privacy.includeArchived,
        );
    if (!context.mounted) return null;
  }
  final ok = await confirmAiSend(
    context,
    ref,
    model: model,
    summary: AiSendSummary(
      words: recent.fold<int>(
        0,
        (sum, diary) => sum + TextStats.countWords(diary.contentText),
      ),
      entries: recent.length,
    ),
  );
  if (!ok || !context.mounted) return null;
  final kit = AiPromptKit.resolve(
    prefs: prefs,
    appLocale: Localizations.localeOf(context),
  );
  final today = <String>[
    DateFormat.yMMMMEEEEd(kit.l10n.localeName).format(date),
    // 农历与节气只对中文提示词有意义。
    if (kit.l10n.localeName == 'zh') ...[
      CalendarLunarDay.of(date).date,
      ?CalendarLunarDay.of(date).term,
    ],
    if (weather != null && weather.trim().isNotEmpty) weather.trim(),
  ].join(' · ');
  try {
    final completion = await service.complete(
      model,
      aiPromptsRequest(kit, todayLine: today, recent: recent),
    );
    final prompts = aiParsePrompts(completion.text);
    if (prompts.isEmpty && context.mounted) _hint(context, l10n.aiPromptsEmpty);
    return prompts;
  } catch (error) {
    if (context.mounted) _hint(context, aiErrorMessage(l10n, error));
    return null;
  }
}

void _hint(BuildContext context, String message) {
  unawaited(
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(message)),
    ),
  );
}
