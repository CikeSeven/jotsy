// 写作助手与智能填写的流程编排（编辑页调用）。
//
// 顺序：解析模型（没有可用模型时给出错误）→ 取目标文字（为空时提示）→
// 按隐私设置确认 → 构建提示词 → 交给会话流式生成。确认或解析失败时不发
// 任何请求。每次 await 之后检查 context.mounted（页面可能已离开）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_failure.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/ai/ai_vision.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/text_stats.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../models/ai_built_ins.dart';
import '../providers/ai_providers.dart';
import '../viewmodels/ai_json_output.dart';
import '../viewmodels/ai_labels.dart';
import '../viewmodels/ai_prompt_builder.dart';
import '../viewmodels/ai_task_prompts.dart';
import 'ai_privacy_gate.dart';
import 'ai_writing_session.dart';

/// 用 [action]（或自由指令 [instruction]）处理会话的目标文字。
/// [diary] 提供标题、日期、心情与全文（变量与提示词上下文）。
Future<void> runAiWriting(
  BuildContext context,
  WidgetRef ref,
  AiWritingSession session, {
  AiActionInfo? action,
  String? instruction,
  required AiContextDiary diary,
}) async {
  final l10n = context.l10n;
  final target = session.targetFor(action);
  if (target == null || target.isEmpty) {
    _hint(context, l10n.aiPanelEmptyTarget);
    return;
  }
  final service = await ref.read(aiServiceProvider.future);
  if (!context.mounted) return;
  final model = service.resolve(AiTaskKind.writing);
  if (model == null) {
    _hint(context, l10n.aiErrorNotConfigured);
    return;
  }
  final ok = await confirmAiSend(
    context,
    ref,
    model: model,
    summary: AiSendSummary(words: TextStats.countWords(target.text)),
  );
  if (!ok || !context.mounted) return;
  final kit = AiPromptKit.resolve(
    prefs: ref.read(aiPreferencesProvider),
    appLocale: Localizations.localeOf(context),
    sample: target.text,
  );
  final request = aiWritingRequest(
    kit,
    action: action,
    instruction: instruction,
    targetText: target.text,
    diary: diary,
  );
  await session.start(
    service: service,
    model: model,
    request: request,
    target: target,
    action: action,
    instruction: instruction,
  );
}

/// 复制结果到剪贴板并提示。
Future<void> copyAiResult(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) _hint(context, context.l10n.aiPanelCopied);
}

/// 智能填写：一次请求同时拿到标题、标签与心情的建议。没有正文时提示；
/// 失败时提示原因并返回 null。
Future<AiSuggestion?> requestAiSuggestion(
  BuildContext context,
  WidgetRef ref, {
  required AiContextDiary diary,
  required List<String> tags,
  required List<String> moods,
}) async {
  final l10n = context.l10n;
  if (diary.contentText.trim().isEmpty && diary.title.trim().isEmpty) {
    _hint(context, l10n.aiSuggestNeedContent);
    return null;
  }
  final service = await ref.read(aiServiceProvider.future);
  final model = service.resolve(AiTaskKind.suggest);
  if (model == null) {
    if (context.mounted) _hint(context, l10n.aiErrorNotConfigured);
    return null;
  }
  if (!context.mounted) return null;
  final ok = await confirmAiSend(
    context,
    ref,
    model: model,
    summary: AiSendSummary(
      words:
          TextStats.countWords(diary.contentText) +
          TextStats.countWords(diary.title),
    ),
  );
  if (!ok || !context.mounted) return null;
  final kit = AiPromptKit.resolve(
    prefs: ref.read(aiPreferencesProvider),
    appLocale: Localizations.localeOf(context),
    sample: diary.contentText,
  );
  try {
    final completion = await service.complete(
      model,
      aiSuggestRequest(kit, diary: diary, tags: tags, moods: moods),
    );
    final suggestion = AiSuggestion.parse(
      completion.text,
      existingTags: tags,
      moods: moods,
    );
    if (suggestion.isEmpty && context.mounted) {
      _hint(context, l10n.aiSuggestNothing);
    }
    return suggestion;
  } catch (error) {
    if (context.mounted) _hint(context, aiErrorMessage(l10n, error));
    return null;
  }
}

/// 用视觉模型描述一张图片，返回描述文字（失败时提示并返回 null）。
Future<String?> describeAiImage(
  BuildContext context,
  WidgetRef ref,
  String source,
) async {
  final l10n = context.l10n;
  final prefs = ref.read(aiPreferencesProvider);
  final service = await ref.read(aiServiceProvider.future);
  final model = service.resolve(AiTaskKind.vision);
  if (model == null) {
    if (context.mounted) _hint(context, l10n.aiErrorNotConfigured);
    return null;
  }
  if (!model.model.supportsVision) {
    if (context.mounted) _hint(context, l10n.aiImageNoVision);
    return null;
  }
  final image = await AiVisionImages.load(source, maxSide: prefs.visionMaxSide);
  if (image == null || !context.mounted) return null;
  final ok = await confirmAiSend(
    context,
    ref,
    model: model,
    summary: const AiSendSummary(words: 0, images: 1),
  );
  if (!ok || !context.mounted) return null;
  _hint(context, l10n.aiImageDescribing);
  final kit = AiPromptKit.resolve(
    prefs: prefs,
    appLocale: Localizations.localeOf(context),
  );
  try {
    final completion = await service.complete(
      model,
      aiDescribeImageRequest(kit, image),
    );
    final text = completion.text.trim();
    return text.isEmpty ? null : text;
  } on AiException catch (error) {
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
