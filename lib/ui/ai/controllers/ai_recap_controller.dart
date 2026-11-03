// 回顾的生成流程（回顾页持有，页面离开即停止）。
//
// 顺序：解析模型 → 一次性读出范围里的日记（`getAiContextDiaries`，排除
// 回收站、未解封的胶囊、私密日记与用户在 AI 隐私里排除的本子和标签）→
// 本地统计 → 按字数预算规划（[aiPlanRecap]）→ 分块时先用“快速模型”逐块
// 总结（显示“正在读第 i 部分”）→ 流式写最终回顾 → 完成即
// 存进 `ai_results`（kind recap）。
// 每个阶段都在实际请求前确认实际模型，主模型的确认不授权辅助服务商。
//
// 状态边界：[phase] 从 idle 进入 reading（只在分块时）/ writing，结束于
// done / stopped / failed / empty；[stop] 取消当前请求（分块总结或最终
// 生成），已写了一半的回顾不保存。重新生成先停掉上一次（世代号防止旧的
// 异步回调改写新状态）。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_failure.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/http_cancel_token.dart';
import '../../../l10n/app_localizations.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_preference_parts.dart';
import '../models/ai_recap_range.dart';
import '../providers/ai_providers.dart';
import '../viewmodels/ai_citations.dart';
import '../viewmodels/ai_labels.dart';
import '../viewmodels/ai_prompt_builder.dart';
import '../viewmodels/ai_recap_material.dart';
import '../viewmodels/ai_task_prompts.dart';
import 'ai_privacy_gate.dart';
import 'ai_stream_run.dart';

enum AiRecapPhase {
  idle,

  /// 分块总结中（[AiRecapController.chunkIndex] / [AiRecapController.chunkTotal]）。
  reading,

  /// 流式写最终回顾。
  writing,
  done,
  stopped,
  failed,

  /// 范围里没有可回顾的日记。
  empty,
}

/// 一次回顾要什么。
@immutable
class AiRecapSpec {
  const AiRecapSpec({
    required this.range,
    required this.scope,
    required this.listScope,
    required this.sections,
    required this.personaId,
  });

  final AiRecapRange range;
  final AiRecapScope scope;

  /// [scope] 换算成的查询范围（日记本时含子孙本子，见 `notebookStatsScope`）。
  final DiaryListScope listScope;
  final List<AiRecapSection> sections;
  final String? personaId;
}

class AiRecapController extends ChangeNotifier {
  final AiStreamRun run = AiStreamRun();

  AiRecapPhase _phase = AiRecapPhase.idle;
  int _chunkIndex = 0;
  int _chunkTotal = 0;
  AiRecapStats? _stats;
  Object? _error;
  String? _savedResultId;
  Map<String, String> _refs = const <String, String>{};
  HttpCancelToken? _chunkToken;
  int _generation = 0;
  bool _disposed = false;

  AiRecapPhase get phase => _phase;
  int get chunkIndex => _chunkIndex;
  int get chunkTotal => _chunkTotal;
  AiRecapStats? get stats => _stats;
  Object? get error => _error ?? run.error;

  /// 完成后保存的回顾（`ai_results` 业务 id）。
  String? get savedResultId => _savedResultId;

  /// 这次发送的日记：引用编号 → 日记业务 id（点引用胶囊打开原文）。
  Map<String, String> get refs => _refs;

  bool get busy =>
      _phase == AiRecapPhase.reading || _phase == AiRecapPhase.writing;

  /// 生成一份回顾。返回时流程已结束（或被下一次取代）。
  Future<void> generate(
    BuildContext context,
    WidgetRef ref,
    AiRecapSpec spec,
  ) async {
    stop();
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    _set(AiRecapPhase.idle, clear: true);

    final service = await ref.read(aiServiceProvider.future);
    if (!current()) return;
    final model = service.resolve(AiTaskKind.recap);
    if (model == null) {
      _fail(const AiException(AiFailureKind.notConfigured));
      return;
    }
    final prefs = ref.read(aiPreferencesProvider);
    final diaries = await ref
        .read(appDatabaseProvider)
        .getAiContextDiaries(
          start: spec.range.start,
          end: spec.range.end,
          scope: spec.listScope,
          excludedNotebookIds: prefs.privacy.excludedNotebookIds,
          excludedTagNames: prefs.privacy.excludedTagNames,
          includeArchived: prefs.privacy.includeArchived,
        );
    if (!current()) return;
    if (diaries.isEmpty) {
      _set(AiRecapPhase.empty);
      return;
    }
    final stats = _stats = AiRecapStats.of(diaries);
    final plan = aiPlanRecap(diaries, budget: prefs.privacy.contextBudget);
    _refs = <String, String>{
      for (final item in plan.diaries) item.ref: item.diary.diaryId,
    };
    _notify();
    if (!context.mounted) return;
    final kit = AiPromptKit.resolve(
      prefs: prefs,
      appLocale: locale,
      sample: [for (final d in diaries.take(5)) d.contentText].join('\n'),
    );
    final promptPersona = aiPersonaById(
      kit.l10n,
      prefs,
      spec.personaId,
      use: AiPersonaUse.recap,
    );
    final shownPersona = aiPersonaById(
      l10n,
      prefs,
      promptPersona.id,
      use: AiPersonaUse.recap,
    );

    // 分块：先逐块总结（快速模型；没有单独设置时就是回顾的模型）。
    final summaries = <String>[];
    if (plan.chunked) {
      final utility = service.resolve(AiTaskKind.utility) ?? model;
      _chunkTotal = plan.chunks.length;
      for (var i = 0; i < plan.chunks.length; i++) {
        _chunkIndex = i + 1;
        _set(AiRecapPhase.reading);
        final token = _chunkToken = HttpCancelToken();
        try {
          if (!context.mounted) return;
          final chunk = plan.chunks[i];
          final ok = await confirmAiSend(
            context,
            ref,
            model: utility,
            summary: AiSendSummary(
              words: chunk.fold<int>(0, (sum, diary) => sum + diary.maxWords),
              entries: chunk.length,
            ),
          );
          if (!current()) return;
          if (!ok || !context.mounted || token.isCancelled) {
            _set(token.isCancelled ? AiRecapPhase.stopped : AiRecapPhase.idle);
            return;
          }
          final completion = await service.complete(
            utility,
            aiRecapChunkRequest(kit, chunk),
            cancelToken: token,
          );
          if (!current()) return;
          summaries.add(aiCleanOutput(completion.text));
        } on AiException catch (error) {
          if (!current()) return;
          if (error.kind == AiFailureKind.cancelled) {
            _set(AiRecapPhase.stopped);
          } else {
            _fail(error);
          }
          return;
        } catch (error) {
          if (!current()) return;
          _fail(error);
          return;
        } finally {
          if (identical(_chunkToken, token)) _chunkToken = null;
        }
      }
    }

    if (!current() || !context.mounted) return;
    _set(AiRecapPhase.writing);
    final token = _chunkToken = HttpCancelToken();
    final ok = await confirmAiSend(
      context,
      ref,
      model: model,
      summary: AiSendSummary(words: plan.words, entries: plan.diaries.length),
    );
    if (identical(_chunkToken, token)) _chunkToken = null;
    if (!current()) return;
    if (!ok || !context.mounted || token.isCancelled) {
      _set(token.isCancelled ? AiRecapPhase.stopped : AiRecapPhase.idle);
      return;
    }
    final request = aiRecapRequest(
      kit,
      period: aiRecapRangeText(kit.l10n, spec.range),
      sections: spec.sections,
      stats: stats,
      persona: promptPersona,
      diaries: plan.chunked ? const [] : plan.diaries,
      summaries: summaries,
    );
    await run.start(
      (token) => service.stream(model, request, cancelToken: token),
    );
    if (!current()) return;
    switch (run.status) {
      case AiRunStatus.done when run.hasText:
        break;
      case AiRunStatus.stopped:
        _set(AiRecapPhase.stopped);
        return;
      case AiRunStatus.failed:
        _fail(run.error ?? const AiException(AiFailureKind.badResponse));
        return;
      default:
        _fail(const AiException(AiFailureKind.badResponse));
        return;
    }

    final content = aiCleanOutput(run.text);
    final cited = aiCitedRefs(content).toSet();
    final citations = [
      for (final item in plan.diaries)
        if (cited.contains(item.ref))
          AiCitation(
            ref: item.ref,
            diaryId: item.diary.diaryId,
            title: item.diary.title,
            date: item.diary.createdAt,
          ),
    ];
    final usage = run.usage;
    final id = await ref
        .read(appDatabaseProvider)
        .addAiResult(
          kind: AiResultKind.recap,
          content: content,
          periodStart: spec.range.start,
          periodEnd: spec.range.end,
          scopeJson: spec.scope.encode(spec.range.preset),
          title: aiRecapRangeText(l10n, spec.range),
          personaId: shownPersona.id,
          metaJson: jsonEncode(<String, Object?>{
            'personaName': shownPersona.name,
            'personaEmoji': shownPersona.emoji,
            'provider': model.provider.name,
            'model': model.model.id,
            'sections': [for (final s in spec.sections) s.name],
            'stats': stats.toJson(),
            'citations': [for (final c in citations) c.toJson()],
            if (run.reasoning.trim().isNotEmpty) 'reasoning': run.reasoning,
            if (usage != null) ...<String, Object?>{
              'inputTokens': usage.inputTokens,
              'outputTokens': usage.outputTokens,
            },
          }),
        );
    if (!current()) return;
    _savedResultId = id;
    _set(AiRecapPhase.done);
  }

  /// 停止（分块总结或最终生成）。
  void stop() {
    _chunkToken?.cancel();
    _chunkToken = null;
    run.stop();
  }

  void _fail(Object error) {
    _error = error;
    _set(AiRecapPhase.failed);
  }

  void _set(AiRecapPhase phase, {bool clear = false}) {
    if (clear) {
      _error = null;
      _stats = null;
      _savedResultId = null;
      _refs = const <String, String>{};
      _chunkIndex = 0;
      _chunkTotal = 0;
      run.reset();
    }
    _phase = phase;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _chunkToken?.cancel();
    run.dispose();
    super.dispose();
  }
}

/// 存进回顾 meta 的信息（显示已保存的回顾用）。
@immutable
class AiRecapMeta {
  const AiRecapMeta({
    this.personaName,
    this.personaEmoji,
    this.model,
    this.stats,
    this.citations = const <AiCitation>[],
    this.reasoning = '',
  });

  factory AiRecapMeta.decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const AiRecapMeta();
      String? text(String key) =>
          json[key] is String ? json[key] as String : null;
      final citations = json['citations'];
      return AiRecapMeta(
        personaName: text('personaName'),
        personaEmoji: text('personaEmoji'),
        model: text('model'),
        stats: AiRecapStats.fromJson(json['stats']),
        reasoning: text('reasoning') ?? '',
        citations: [
          if (citations is List)
            for (final item in citations)
              if (AiCitation.fromJson(item) case final citation?) citation,
        ],
      );
    } on FormatException {
      return const AiRecapMeta();
    }
  }

  final String? personaName;
  final String? personaEmoji;
  final String? model;
  final AiRecapStats? stats;
  final List<AiCitation> citations;

  /// 生成时的思考过程（模型给出时才有）。
  final String reasoning;
}
