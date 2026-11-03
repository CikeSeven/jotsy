// 与日记对话的一轮问答（对话页持有，页面离开即停止）。
//
// 顺序（[AiChatController.send]）：
// 1. 还没有对话时新建一行（`ai_conversations`），问题先落库（用户消息）；
// 2. 检索：按对话范围与 AI 设置的检索方式找日记——
//    - 固定一篇（预览页“继续聊聊”）：只读那一篇，私密日记只在用户允许时；
//    - 时间范围 / 最近 N 天：读这段时间的日记，按问题的关键词排序；
//    - 全部 / 关键词：按本地关键词查，查不到时退回最近 N 天；
//    - 智能：先确认“快速模型”的实际主机，再把问题转成检索计划（关键词
//      + 可能的日期范围）；取消确认即结束，读不出计划或请求失败退回本地关键词；
//    多篇一律经 `getAiContextDiaries`（排除回收站、未解封的胶囊、私密日记与
//    用户排除的本子和标签），按相关程度取前 N 篇（“最多引用”）、放进字数
//    预算，再按时间先后编号 `[D1]…`；
// 3. 发送前确认（多篇时按设置询问）；
// 4. 流式回答；结束时把回答落库（完成 / 停止 / 出错，出错的原因记在 meta），
//    引用只记回答里真的用到的那几篇；
// 5. 第一轮结束后给对话起标题：先用问题开头，开了“自动起标题”再请快速
//    模型起一个（另行确认实际主机，取消或失败就保留问题开头）。
//
// 状态边界：[phase] idle → planning（只在智能检索）→ searching → answering
// → idle；[stop] 取消检索计划或回答；页面离开（[dispose]）时正在生成的
// 回答按“已停止”保存已经收到的部分。世代号防止旧的异步回调改写新状态。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_failure.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/http_cancel_token.dart';
import '../../../utils/text_stats.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_chat_scope.dart';
import '../models/ai_preference_parts.dart';
import '../models/ai_preferences.dart';
import '../providers/ai_providers.dart';
import '../viewmodels/ai_chat_prompts.dart';
import '../viewmodels/ai_citations.dart';
import '../viewmodels/ai_context_budget.dart';
import '../viewmodels/ai_prompt_builder.dart';
import '../viewmodels/ai_retrieval.dart';
import '../viewmodels/ai_task_prompts.dart';
import 'ai_privacy_gate.dart';
import 'ai_stream_run.dart';

enum AiChatPhase { idle, planning, searching, answering }

class AiChatController extends ChangeNotifier {
  AiChatController({
    required this.database,
    this.conversationId,
    this.scope = const AiChatScope.auto(),
    this.personaId,
  });

  final AppDatabase database;

  /// 当前对话；第一次发送前为 null。
  String? conversationId;
  AiChatScope scope;
  String? personaId;

  /// 这次打开页面时临时换用的模型（不保存）；null 用“对话”任务的模型。
  AiModelRef? modelRef;

  final AiStreamRun run = AiStreamRun();

  AiChatPhase _phase = AiChatPhase.idle;
  List<AiCitation> _citations = const <AiCitation>[];
  AiResolvedModel? _model;
  HttpCancelToken? _planToken;
  HttpCancelToken? _titleToken;
  int _generation = 0;
  bool _disposed = false;

  AiChatPhase get phase => _phase;
  bool get busy => _phase != AiChatPhase.idle;

  /// 正在生成的这一轮放进上下文的日记（引用胶囊用）。
  List<AiCitation> get pendingCitations => _citations;

  /// 发一个问题（[resend] 时问题已经在库里，不再追加用户消息）。
  Future<void> send(
    BuildContext context,
    WidgetRef ref,
    String question, {
    bool resend = false,
  }) async {
    final text = question.trim();
    if (text.isEmpty || busy) return;
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    final locale = Localizations.localeOf(context);
    final prefs = ref.read(aiPreferencesProvider);
    final service = await ref.read(aiServiceProvider.future);
    if (!current()) return;
    final model = _model = service.resolve(AiTaskKind.chat, override: modelRef);

    var id = conversationId;
    if (id == null) {
      id = conversationId = await database.createAiConversation(
        personaId: personaId,
        scopeJson: scope.encode(),
      );
      _notify();
    }
    final history = await database.getAiMessages(id);
    if (!resend) {
      await database.addAiMessage(
        conversationId: id,
        role: AiMessageRole.user,
        content: text,
      );
    } else if (history.isNotEmpty && history.last.role == AiMessageRole.user) {
      history.removeLast();
    }
    if (!current()) return;
    if (model == null) {
      await _saveError(id, const AiException(AiFailureKind.notConfigured));
      return;
    }

    final kit = AiPromptKit.resolve(
      prefs: prefs,
      appLocale: locale,
      sample: text,
    );
    if (!context.mounted) return;
    _set(
      prefs.retrieval == AiRetrievalMode.smart &&
              scope.kind == AiChatScopeKind.auto
          ? AiChatPhase.planning
          : AiChatPhase.searching,
    );
    final List<AiBudgetedDiary> diaries;
    try {
      diaries = await _retrieve(
        context,
        ref,
        service,
        kit,
        prefs,
        text,
        model: model,
        current: current,
      );
    } on AiException catch (error) {
      if (!current()) return;
      if (error.kind == AiFailureKind.cancelled) {
        _set(AiChatPhase.idle);
      } else {
        await _saveError(id, error);
      }
      return;
    }
    if (!current()) return;
    if (!context.mounted) {
      _set(AiChatPhase.idle);
      return;
    }
    final ok = await confirmAiSend(
      context,
      ref,
      model: model,
      summary: AiSendSummary(
        words:
            diaries.fold<int>(0, (sum, d) => sum + d.maxWords) +
            TextStats.countWords(text),
        entries: diaries.length,
      ),
    );
    if (!current()) return;
    if (!ok || !context.mounted) {
      _set(AiChatPhase.idle);
      return;
    }
    final persona = aiPersonaById(
      kit.l10n,
      prefs,
      personaId,
      use: AiPersonaUse.chat,
    );
    _citations = [
      for (final item in diaries)
        AiCitation(
          ref: item.ref,
          diaryId: item.diary.diaryId,
          title: item.diary.title,
          date: item.diary.createdAt,
        ),
    ];
    _set(AiChatPhase.answering);
    final request = aiChatRequest(
      kit,
      history: history,
      question: text,
      diaries: diaries,
      today: DateTime.now(),
      persona: persona,
    );
    await run.start(
      (token) => service.stream(model, request, cancelToken: token),
    );
    if (!current()) return;
    await _saveAnswer(id);
    if (!current()) return;
    _set(AiChatPhase.idle);
    if (history.isEmpty) {
      if (!context.mounted) return;
      unawaited(
        _title(
          context,
          ref,
          id,
          service,
          kit,
          prefs,
          text,
          diaries.length,
          current,
        ),
      );
    }
  }

  /// 重新生成最后一个回答：删掉它（与之后的消息），按最后一个问题再问。
  Future<void> regenerate(BuildContext context, WidgetRef ref) async {
    final id = conversationId;
    if (id == null || busy) return;
    final messages = await database.getAiMessages(id);
    final lastUser = messages.lastIndexWhere(
      (m) => m.role == AiMessageRole.user,
    );
    if (lastUser < 0) return;
    await database.deleteAiMessages([
      for (final m in messages.skip(lastUser + 1)) m.messageId,
    ]);
    if (!context.mounted) return;
    await send(context, ref, messages[lastUser].content, resend: true);
  }

  /// 编辑并重发最后一个问题：删掉它与之后的回答，再发 [question]。
  Future<void> editLast(
    BuildContext context,
    WidgetRef ref,
    String question,
  ) async {
    final id = conversationId;
    if (id == null || busy) return;
    final messages = await database.getAiMessages(id);
    final lastUser = messages.lastIndexWhere(
      (m) => m.role == AiMessageRole.user,
    );
    if (lastUser < 0) return;
    await database.deleteAiMessages([
      for (final m in messages.skip(lastUser)) m.messageId,
    ]);
    if (!context.mounted) return;
    await send(context, ref, question);
  }

  /// 换范围 / 人设：对话已存在时一并保存。
  Future<void> updateScope(AiChatScope value) async {
    scope = value;
    _notify();
    final id = conversationId;
    if (id != null) {
      await database.updateAiConversation(id, scopeJson: value.encode());
    }
  }

  Future<void> updatePersona(String? value) async {
    personaId = value;
    _notify();
    final id = conversationId;
    if (id != null) {
      await database.updateAiConversation(id, personaId: value);
    }
  }

  void updateModel(AiModelRef? value) {
    modelRef = value;
    _notify();
  }

  /// 停止检索计划或回答（回答已收到的部分会保存）。
  void stop() {
    _planToken?.cancel();
    _planToken = null;
    _titleToken?.cancel();
    run.stop();
  }

  // ------------------------------------------------------------ 检索

  Future<List<AiBudgetedDiary>> _retrieve(
    BuildContext context,
    WidgetRef ref,
    AiService service,
    AiPromptKit kit,
    AiPreferences prefs,
    String question, {
    required AiResolvedModel model,
    required bool Function() current,
  }) async {
    final privacy = prefs.privacy;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Future<List<AiContextDiary>> query({
      DateTime? start,
      DateTime? end,
      List<String> keywords = const <String>[],
    }) => database.getAiContextDiaries(
      start: start,
      end: end,
      keywords: keywords,
      excludedNotebookIds: privacy.excludedNotebookIds,
      excludedTagNames: privacy.excludedTagNames,
      includeArchived: privacy.includeArchived,
      newestFirst: true,
      limit: 400,
    );

    DateTime daysAgo(int days) =>
        DateTime(today.year, today.month, today.day - days + 1);
    DateTime dayAfter(DateTime day) =>
        DateTime(day.year, day.month, day.day + 1);

    Future<List<AiContextDiary>> recent(int days) =>
        query(start: daysAgo(days), end: dayAfter(today));

    /// 按关键词查，查不到退回最近 N 天。
    Future<List<AiContextDiary>> byKeywords(List<String> keywords) async {
      if (keywords.isNotEmpty) {
        final found = await query(keywords: keywords);
        if (found.isNotEmpty) return found;
      }
      return recent(prefs.recentDays);
    }

    var keywords = aiQueryKeywords(question);
    List<AiContextDiary> candidates;
    switch (scope.kind) {
      case AiChatScopeKind.diary:
        final diary = await database.getAiDiary(scope.diaryId!);
        final allowed =
            diary != null &&
            (privacy.allowPrivate ||
                !(await database.isDiaryPrivate(diary.diaryId)));
        if (!allowed) return const <AiBudgetedDiary>[];
        // 整篇发送，只受总字数限制；maxWords 取实际字数，确认面板里的
        // “发送字数”才不会显示成整个预算。
        final words =
            TextStats.countWords(diary.contentText) +
            TextStats.countWords(diary.title);
        return [
          AiBudgetedDiary(
            diary: diary,
            ref: 'D1',
            maxWords: words < privacy.contextBudget
                ? words
                : privacy.contextBudget,
          ),
        ];
      case AiChatScopeKind.range:
        candidates = await query(start: scope.start, end: dayAfter(scope.end!));
      case AiChatScopeKind.recent:
        candidates = await recent(scope.days);
      case AiChatScopeKind.all:
        candidates = await byKeywords(keywords);
      case AiChatScopeKind.auto:
        switch (prefs.retrieval) {
          case AiRetrievalMode.recent:
            candidates = await recent(prefs.recentDays);
          case AiRetrievalMode.keyword:
            candidates = await byKeywords(keywords);
          case AiRetrievalMode.smart:
            if (!context.mounted) return const <AiBudgetedDiary>[];
            final plan = await _plan(
              context,
              ref,
              service,
              kit,
              question,
              model,
              current,
            );
            if (!current()) return const <AiBudgetedDiary>[];
            _set(AiChatPhase.searching);
            if (plan != null) {
              keywords = {...plan.keywords, ...keywords}.take(16).toList();
            }
            if (plan != null && plan.hasDates) {
              candidates = await query(
                start: plan.from,
                end: plan.to == null ? null : dayAfter(plan.to!),
              );
            } else {
              candidates = await byKeywords(keywords);
            }
        }
    }
    final ranked = aiRankDiaries(
      candidates,
      keywords,
      now: now,
    ).take(prefs.maxCitations).toList();
    final kept = aiBudgetDiaries(ranked, budget: privacy.contextBudget)
      ..sort((a, b) => a.diary.createdAt.compareTo(b.diary.createdAt));
    return [
      for (var i = 0; i < kept.length; i++)
        AiBudgetedDiary(
          diary: kept[i].diary,
          ref: 'D${i + 1}',
          maxWords: kept[i].maxWords,
        ),
    ];
  }

  /// 智能检索的计划；读不出或请求失败（取消除外）时为 null。
  Future<AiRetrievalPlan?> _plan(
    BuildContext context,
    WidgetRef ref,
    AiService service,
    AiPromptKit kit,
    String question,
    AiResolvedModel model,
    bool Function() current,
  ) async {
    final utility = service.resolve(AiTaskKind.utility) ?? model;
    final token = _planToken = HttpCancelToken();
    try {
      final request = aiRetrievalPlanRequest(
        kit,
        question: question,
        today: DateTime.now(),
      );
      // 检索计划同样包含问题与“关于我”，必须在第一字节发出前确认它的
      // 实际模型。取消不能当成计划失败后继续检索，否则仍可能发送回答请求。
      final ok = await confirmAiSend(
        context,
        ref,
        model: utility,
        summary: AiSendSummary(
          words: TextStats.countWords(
            '${request.system}\n${request.messages.single.text}',
          ),
        ),
      );
      if (!ok || !current() || !context.mounted || token.isCancelled) {
        throw const AiException(AiFailureKind.cancelled);
      }
      final completion = await service.complete(
        utility,
        request,
        cancelToken: token,
      );
      return AiRetrievalPlan.parse(completion.text);
    } on AiException catch (error) {
      if (error.kind == AiFailureKind.cancelled) rethrow;
      return null;
    } catch (_) {
      return null;
    } finally {
      if (identical(_planToken, token)) _planToken = null;
    }
  }

  // ------------------------------------------------------------ 保存

  /// 把这一轮的回答落库（完成 / 停止 / 出错）。停止且一个字都没收到时
  /// 不留空消息。
  Future<void> _saveAnswer(String conversationId) async {
    final status = switch (run.status) {
      AiRunStatus.done => AiMessageStatus.done,
      AiRunStatus.stopped => AiMessageStatus.stopped,
      _ => AiMessageStatus.error,
    };
    if (status == AiMessageStatus.stopped && !run.hasText) return;
    if (status == AiMessageStatus.error) {
      await _saveError(
        conversationId,
        run.error ?? const AiException(AiFailureKind.badResponse),
        partial: run.text,
      );
      return;
    }
    await database.addAiMessage(
      conversationId: conversationId,
      role: AiMessageRole.assistant,
      content: aiCleanOutput(run.text),
      reasoning: run.reasoning,
      citationsJson: AiCitation.encodeList(_cited(run.text)),
      metaJson: _meta(),
      status: status,
    );
  }

  Future<void> _saveError(
    String conversationId,
    Object error, {
    String partial = '',
  }) async {
    final failure = error is AiException ? error : null;
    await database.addAiMessage(
      conversationId: conversationId,
      role: AiMessageRole.assistant,
      content: partial,
      citationsJson: AiCitation.encodeList(_cited(partial)),
      metaJson: _meta(
        extra: <String, Object?>{
          'errorKind': (failure?.kind ?? AiFailureKind.badResponse).name,
          if (failure?.statusCode case final code?) 'statusCode': code,
          'errorDetail':
              failure?.providerMessage ?? failure?.detail ?? '$error',
        },
      ),
      status: AiMessageStatus.error,
    );
    if (!_disposed) _set(AiChatPhase.idle);
  }

  List<AiCitation> _cited(String text) {
    final refs = aiCitedRefs(text).toSet();
    return [
      for (final citation in _citations)
        if (refs.contains(citation.ref)) citation,
    ];
  }

  String _meta({Map<String, Object?> extra = const <String, Object?>{}}) {
    final model = _model;
    final usage = run.usage;
    return jsonEncode(<String, Object?>{
      if (model != null) ...<String, Object?>{
        'provider': model.provider.name,
        'model': model.model.id,
      },
      // 这一轮放进上下文的篇数（“参考了 N 篇”里没被引用的也算）。
      'contextEntries': _citations.length,
      if (usage != null) ...<String, Object?>{
        'inputTokens': usage.inputTokens,
        'outputTokens': usage.outputTokens,
      },
      ...extra,
    });
  }

  Future<void> _title(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
    AiService service,
    AiPromptKit kit,
    AiPreferences prefs,
    String question,
    int entries,
    bool Function() current,
  ) async {
    final row = await database.getAiConversation(conversationId);
    if (row == null || row.title.trim().isNotEmpty) return;
    final fallback = question.replaceAll(RegExp(r'\s+'), ' ').trim();
    await database.updateAiConversation(
      conversationId,
      title: fallback.length > 24 ? '${fallback.substring(0, 24)}…' : fallback,
    );
    if (!prefs.autoTitle || !current()) return;
    final model = service.resolve(AiTaskKind.utility);
    if (model == null) return;
    final token = _titleToken = HttpCancelToken();
    try {
      final messages = await database.getAiMessages(conversationId);
      if (!current() || !context.mounted || token.isCancelled) return;
      final answer = messages.lastWhere(
        (m) => m.role == AiMessageRole.assistant,
        orElse: () => messages.last,
      );
      final request = aiConversationTitleRequest(
        kit,
        question: question,
        answer: answer.content,
      );
      final ok = await confirmAiSend(
        context,
        ref,
        model: model,
        summary: AiSendSummary(
          words: TextStats.countWords(
            '${request.system}\n${request.messages.single.text}',
          ),
          entries: entries,
        ),
      );
      if (!ok || !current() || !context.mounted || token.isCancelled) return;
      final completion = await service.complete(
        model,
        request,
        cancelToken: token,
      );
      final title = aiCleanOutput(
        completion.text,
      ).split('\n').first.replaceAll(RegExp(r'^[#*\s]+|[*\s]+$'), '');
      if (title.isEmpty || title.length > 40) return;
      await database.updateAiConversation(conversationId, title: title);
    } catch (_) {
      // 起标题失败不打扰用户，保留问题开头。
    } finally {
      if (identical(_titleToken, token)) _titleToken = null;
    }
  }

  void _set(AiChatPhase phase) {
    _phase = phase;
    if (phase == AiChatPhase.idle) _citations = const <AiCitation>[];
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // 页面离开：正在生成的回答按“已停止”保存已收到的部分（库在应用级，
    // 页面没了照样能写）。
    final id = conversationId;
    if (_phase == AiChatPhase.answering && run.hasText && id != null) {
      unawaited(
        database.addAiMessage(
          conversationId: id,
          role: AiMessageRole.assistant,
          content: aiCleanOutput(run.text),
          reasoning: run.reasoning,
          citationsJson: AiCitation.encodeList(_cited(run.text)),
          metaJson: _meta(),
          status: AiMessageStatus.stopped,
        ),
      );
    }
    _disposed = true;
    _generation++;
    _planToken?.cancel();
    _titleToken?.cancel();
    run.dispose();
    super.dispose();
  }
}

/// 存在消息 meta 里的出错原因，还原成 [AiException]（给 `AiErrorView`）。
AiException? aiMessageError(AiMessageRow row) {
  if (row.status != AiMessageStatus.error) return null;
  try {
    final meta = jsonDecode(row.meta);
    if (meta is Map) {
      final name = meta['errorKind'];
      var kind = AiFailureKind.badResponse;
      for (final value in AiFailureKind.values) {
        if (value.name == name) kind = value;
      }
      final code = meta['statusCode'];
      final detail = meta['errorDetail'];
      return AiException(
        kind,
        statusCode: code is int ? code : null,
        detail: detail is String ? detail : null,
      );
    }
  } on FormatException {
    // 落到下面。
  }
  return const AiException(AiFailureKind.badResponse);
}
