// 读后回应：生成、保存与自动回应。
//
// 生成中的回应不属于某个页面：预览页翻走、返回后再回来仍能看到进度，所以
// 进行中的任务放在常驻的 [aiReplyJobsProvider]（按日记业务 id 一篇一个）。
// 生成完成即写进 `ai_results`（kind reply）并移除任务；失败或停止的任务
// 留着显示原因与重试，直到用户关掉。
//
// 隐私：私密日记只在用户允许时可以；未解封的胶囊不回应（预览页不建正文，
// 入口本来就没有；自动回应在发表时跳过胶囊）。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/ai_vision.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/text_stats.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_preference_parts.dart';
import '../models/ai_preferences.dart';
import '../providers/ai_providers.dart';
import '../viewmodels/ai_prompt_builder.dart';
import '../viewmodels/ai_task_prompts.dart';
import 'ai_privacy_gate.dart';
import 'ai_stream_run.dart';

/// 一篇日记正在进行（或失败待处理）的回应。
class AiReplyJob {
  AiReplyJob({required this.diaryId, required this.persona});

  final String diaryId;
  final AiPersonaInfo persona;
  final AiStreamRun run = AiStreamRun();
}

/// 进行中的回应，按日记业务 id。常驻：预览页离开再回来进度还在。
final aiReplyJobsProvider =
    NotifierProvider<AiReplyJobs, Map<String, AiReplyJob>>(AiReplyJobs.new);

class AiReplyJobs extends Notifier<Map<String, AiReplyJob>> {
  /// 所有还没释放的任务：onDispose 里不能读 state，另记一份。
  final Set<AiReplyJob> _live = <AiReplyJob>{};

  @override
  Map<String, AiReplyJob> build() {
    ref.onDispose(() {
      for (final job in _live) {
        job.run.dispose();
      }
      _live.clear();
    });
    return const <String, AiReplyJob>{};
  }

  /// 开始一次回应（同一篇已有进行中的回应时忽略）。完成后保存并移除。
  Future<void> start({
    required AiReplyJob job,
    required AiService service,
    required AiResolvedModel model,
    required AiRequest request,
  }) async {
    final existing = state[job.diaryId];
    if (existing != null && existing.run.running) {
      job.run.dispose();
      return;
    }
    if (existing != null) {
      _live.remove(existing);
      existing.run.dispose();
    }
    _live.add(job);
    state = {...state, job.diaryId: job};
    await job.run.start(
      (token) => service.stream(model, request, cancelToken: token),
    );
    final run = job.run;
    if (run.status != AiRunStatus.done || !run.hasText) return;
    await ref
        .read(appDatabaseProvider)
        .addAiResult(
          kind: AiResultKind.reply,
          diaryId: job.diaryId,
          content: aiCleanOutput(run.text),
          personaId: job.persona.id,
          metaJson: jsonEncode(<String, Object?>{
            'personaName': job.persona.name,
            'personaEmoji': job.persona.emoji,
            'provider': model.provider.name,
            'model': model.model.id,
            if (run.reasoning.trim().isNotEmpty) 'reasoning': run.reasoning,
            if (run.usage case final usage?) ...<String, Object?>{
              'inputTokens': usage.inputTokens,
              'outputTokens': usage.outputTokens,
            },
          }),
        );
    if (identical(state[job.diaryId], job)) dismiss(job.diaryId);
  }

  void stop(String diaryId) => state[diaryId]?.run.stop();

  /// 移除任务（失败或停止后用户关掉，或已保存）。
  void dismiss(String diaryId) {
    final job = state[diaryId];
    if (job == null) return;
    state = {
      for (final entry in state.entries)
        if (entry.key != diaryId) entry.key: entry.value,
    };
    // 等这一帧里还在监听它的卡片卸载后再释放。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_live.remove(job)) job.run.dispose();
    });
  }
}

/// 回应用的请求材料：这篇日记与（图片理解开启且模型支持时的）图片。
Future<({AiRequest request, int words, int images})> _buildReplyRequest(
  WidgetRef ref, {
  required AiContextDiary diary,
  required AiPersonaInfo persona,
  required AiResolvedModel model,
  required AiPreferences prefs,
  required Locale locale,
}) async {
  final images =
      prefs.isModuleEnabled(AiModule.vision) &&
          model.model.supportsVision &&
          diary.contentJson != null
      ? await AiVisionImages.fromDiaryContent(
          diary.contentJson!,
          maxCount: prefs.visionMaxImages,
          maxSide: prefs.visionMaxSide,
        )
      : const <AiImagePart>[];
  final kit = AiPromptKit.resolve(
    prefs: prefs,
    appLocale: locale,
    sample: diary.contentText,
  );
  return (
    request: aiReplyRequest(
      kit,
      diary: diary,
      persona: persona,
      images: images,
    ),
    words:
        TextStats.countWords(diary.contentText) +
        TextStats.countWords(diary.title),
    images: images.length,
  );
}

/// 请 AI 回应 [diaryId]（预览页“更多”与回应区的“让 AI 回应…”）。
/// [personaId] 为 null 时用回应的默认人设。
Future<void> requestAiReply(
  BuildContext context,
  WidgetRef ref, {
  required String diaryId,
  String? personaId,
}) async {
  final l10n = context.l10n;
  if (!await aiDiaryAllowed(ref, diaryId)) {
    if (context.mounted) _hint(context, l10n.aiPanelPrivateBlocked);
    return;
  }
  final service = await ref.read(aiServiceProvider.future);
  final diary = await ref.read(appDatabaseProvider).getAiDiary(diaryId);
  if (!context.mounted || diary == null) return;
  final model = service.resolve(AiTaskKind.reply);
  if (model == null) {
    _hint(context, l10n.aiErrorNotConfigured);
    return;
  }
  final prefs = ref.read(aiPreferencesProvider);
  // 人设的提示词用回答语言的 l10n，名称留着界面语言的给卡片显示。
  final kit = AiPromptKit.resolve(
    prefs: prefs,
    appLocale: Localizations.localeOf(context),
    sample: diary.contentText,
  );
  final promptPersona = personaId == null
      ? aiPersonaFor(kit.l10n, prefs, AiPersonaUse.reply)
      : aiPersonaById(kit.l10n, prefs, personaId, use: AiPersonaUse.reply);
  final shownPersona = aiPersonaById(
    l10n,
    prefs,
    promptPersona.id,
    use: AiPersonaUse.reply,
  );
  final material = await _buildReplyRequest(
    ref,
    diary: diary,
    persona: promptPersona,
    model: model,
    prefs: prefs,
    locale: Localizations.localeOf(context),
  );
  if (!context.mounted) return;
  final ok = await confirmAiSend(
    context,
    ref,
    model: model,
    summary: AiSendSummary(words: material.words, images: material.images),
  );
  if (!ok) return;
  await ref
      .read(aiReplyJobsProvider.notifier)
      .start(
        job: AiReplyJob(diaryId: diaryId, persona: shownPersona),
        service: service,
        model: model,
        request: material.request,
      );
}

/// 发表新日记后的自动回应：只在打开了“发表后自动回应”、AI 可用、服务商
/// 已经确认过（自动回应弹不了确认面板）且这篇允许使用 AI 时发送。
Future<void> startAutoAiReply(
  WidgetRef ref, {
  required String diaryId,
  required Locale locale,
  required AppLocalizations l10n,
}) async {
  final prefs = ref.read(aiPreferencesProvider);
  if (!prefs.autoReply ||
      !ref.read(aiFeatureEnabledProvider) ||
      !prefs.isModuleEnabled(AiModule.reply)) {
    return;
  }
  // 直接读存储：发表时这些 provider 可能还没被读过、存储还没加载。
  final store = await ref.read(aiProviderStoreProvider.future);
  final service = await ref.read(aiServiceProvider.future);
  final model = service.resolve(AiTaskKind.reply);
  if (model == null) return;
  final acknowledged = store.config.acknowledgedHosts.contains(
    model.provider.host,
  );
  if (!acknowledged || prefs.privacy.confirm == AiConfirmMode.always) return;
  if (!await aiDiaryAllowed(ref, diaryId)) return;
  final diary = await ref.read(appDatabaseProvider).getAiDiary(diaryId);
  if (diary == null) return;
  final kit = AiPromptKit.resolve(
    prefs: prefs,
    appLocale: locale,
    sample: diary.contentText,
  );
  final promptPersona = aiPersonaFor(kit.l10n, prefs, AiPersonaUse.reply);
  final material = await _buildReplyRequest(
    ref,
    diary: diary,
    persona: promptPersona,
    model: model,
    prefs: prefs,
    locale: locale,
  );
  await ref
      .read(aiReplyJobsProvider.notifier)
      .start(
        job: AiReplyJob(
          diaryId: diaryId,
          persona: aiPersonaById(
            l10n,
            prefs,
            promptPersona.id,
            use: AiPersonaUse.reply,
          ),
        ),
        service: service,
        model: model,
        request: material.request,
      );
}

/// 删除一条回应，提示条带撤销。
Future<void> deleteAiReply(
  BuildContext context,
  WidgetRef ref,
  AiResultRow row,
) async {
  final database = ref.read(appDatabaseProvider);
  final removed = await database.deleteAiResult(row.resultId);
  if (removed == null || !context.mounted) return;
  final l10n = context.l10n;
  await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      persist: false,
      content: Text(l10n.aiReplyDeleted),
      action: SnackBarAction(
        label: l10n.commonUndo,
        onPressed: () => unawaited(database.restoreAiResult(removed)),
      ),
    ),
  );
}

/// 回应卡片上显示的人设（按保存时的名称快照，人设删了也认得出）。
({String name, String emoji}) aiReplyPersonaOf(
  AppLocalizations l10n,
  AiPreferences prefs,
  AiResultRow row,
) {
  try {
    final meta = jsonDecode(row.meta);
    if (meta is Map) {
      final name = meta['personaName'];
      final emoji = meta['personaEmoji'];
      if (name is String && emoji is String) return (name: name, emoji: emoji);
    }
  } on FormatException {
    // 落到下面按 id 找。
  }
  final persona = aiPersonaById(
    l10n,
    prefs,
    row.personaId,
    use: AiPersonaUse.reply,
  );
  return (name: persona.name, emoji: persona.emoji);
}

void _hint(BuildContext context, String message) {
  unawaited(
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(message)),
    ),
  );
}
