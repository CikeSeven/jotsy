// 与日记对话的一轮问答（对话页持有，页面离开即停止）。
//
// 分流：模型支持工具调用、且 AI 设置里“让 AI 使用工具”开着时走智能体
// （`ai_chat_agent.dart`：模型按需调工具查日记、统计、打开页面）；否则走下面
// 的检索问答（`ai_chat_retrieval.dart`）。模型第一步就表明不认工具时，同一个
// 问题改走检索问答。
//
// 检索问答的顺序（[AiChatController.send]）：
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
// → idle，智能体为 idle → working → idle；[stop] 取消检索计划、回答或智能体
// 的这一轮；页面离开（[dispose]）或在抽屉里换到别的对话（[openConversation]
// / [startNew]）时，正在生成的回答按“已停止”保存已经收到的部分（智能体的
// 步骤本来就边做边落库）。世代号防止旧的异步回调改写新状态。
//
// 回答选项（模型、思考强度，[options]）每段对话各自记住：已有对话时随改
// 随存进 `ai_conversations.options`，新对话第一次发送时一并写入。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_agent_loop.dart';
import '../../../core/services/ai/ai_failure.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/http_cancel_token.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/text_stats.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../todos/controllers/todo_reminder_permission.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_chat_scope.dart';
import '../models/ai_conversation_options.dart';
import '../models/ai_guide.dart';
import '../models/ai_preference_parts.dart';
import '../models/ai_preferences.dart';
import '../providers/ai_guide_provider.dart';
import '../providers/ai_providers.dart';
import '../tools/ai_tool.dart';
import '../tools/ai_tool_registry.dart';
import '../viewmodels/ai_agent_prompts.dart';
import '../viewmodels/ai_chat_prompts.dart';
import '../viewmodels/ai_citations.dart';
import '../viewmodels/ai_context_budget.dart';
import '../viewmodels/ai_prompt_builder.dart';
import '../viewmodels/ai_retrieval.dart';
import '../viewmodels/ai_task_prompts.dart';
import 'ai_agent_turn.dart';
import 'ai_privacy_gate.dart';
import 'ai_stream_run.dart';

part 'ai_chat_agent.dart';
part 'ai_chat_retrieval.dart';

enum AiChatPhase {
  idle,
  planning,
  searching,
  answering,

  /// 智能体的一轮在进行（调用工具、流式回答）。
  working,
}

class AiChatController extends ChangeNotifier {
  AiChatController({
    required this.database,
    this.conversationId,
    this.scope = const AiChatScope.auto(),
    this.personaId,
    this.options = AiConversationOptions.defaults,
  });

  final AppDatabase database;

  /// 当前对话；第一次发送前为 null。
  String? conversationId;
  AiChatScope scope;
  String? personaId;

  /// 这段对话的模型与思考强度。
  AiConversationOptions options;

  final AiStreamRun run = AiStreamRun();

  AiChatPhase _phase = AiChatPhase.idle;
  List<AiCitation> _citations = const <AiCitation>[];
  AiResolvedModel? _model;
  HttpCancelToken? _planToken;
  HttpCancelToken? _titleToken;
  HttpCancelToken? _agentToken;
  AiAgentTurn? _agentTurn;
  AiToolNavigation? _autoOpen;
  int _generation = 0;
  bool _disposed = false;

  AiChatPhase get phase => _phase;
  bool get busy => _phase != AiChatPhase.idle;

  /// 正在生成的这一轮放进上下文的日记（引用胶囊用）。
  List<AiCitation> get pendingCitations => _citations;

  /// 正在进行的智能体一轮（界面显示步骤与流式文字）；没有时为 null。
  AiAgentTurn? get agentTurn => _agentTurn;

  /// 取走上一轮要自动打开的页面（用户明确说了“打开…”）。
  AiToolNavigation? takeAutoOpen() {
    final value = _autoOpen;
    _autoOpen = null;
    return value;
  }

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
    // 先等设置读出来：页面带着问题一打开就发送时，偏好可能还是默认值
    // （AI 隐私里排除的日记本、是否使用工具都会被忽略）。
    await ref.read(settingsServiceProvider.future);
    final service = await ref.read(aiServiceProvider.future);
    if (!current()) return;
    final prefs = ref.read(aiPreferencesProvider);
    final model = _model = service.resolve(
      AiTaskKind.chat,
      override: options.model,
    );

    var id = conversationId;
    if (id == null) {
      id = conversationId = await database.createAiConversation(
        personaId: personaId,
        scopeJson: scope.encode(),
        optionsJson: options.encode(),
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
    if (prefs.agent.enabled && service.supportsTools(model)) {
      final answered = await _sendAgent(
        context,
        ref,
        service,
        kit,
        prefs,
        id,
        history,
        text,
        model: model,
        current: current,
      );
      // 模型第一步就表明不认工具时退回检索问答（同一个问题，不重复落库）。
      if (answered || !current() || !context.mounted) return;
    }
    await _sendRetrieval(
      context,
      ref,
      service,
      kit,
      prefs,
      id,
      history,
      text,
      model: model,
      current: current,
    );
  }

  /// 检索问答的一轮：找日记 → 确认 → 流式回答 → 落库 → 起标题。
  Future<void> _sendRetrieval(
    BuildContext context,
    WidgetRef ref,
    AiService service,
    AiPromptKit kit,
    AiPreferences prefs,
    String id,
    List<AiMessageRow> history,
    String text, {
    required AiResolvedModel model,
    required bool Function() current,
  }) async {
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
    ).withThinking(options.thinking);
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

  /// 换模型 / 思考强度：对话已存在时一并保存（新对话在第一次发送时写入）。
  Future<void> updateOptions(AiConversationOptions value) async {
    if (value == options) return;
    options = value;
    _notify();
    final id = conversationId;
    if (id != null) {
      await database.updateAiConversation(id, optionsJson: value.encode());
    }
  }

  /// 读出并换到一段已有的对话（打开页面、历史抽屉）：先放下正在进行的这一
  /// 轮，再按对话行恢复范围、人设与回答选项。
  Future<void> openConversation(String id) async {
    _abandonTurn();
    final row = await database.getAiConversation(id);
    if (_disposed) return;
    conversationId = id;
    if (row != null) {
      scope = AiChatScope.decode(row.scope);
      personaId = row.personaId;
      options = AiConversationOptions.decode(row.options);
    }
    _set(AiChatPhase.idle);
  }

  /// 最近活动的那段对话的模型与思考强度（新对话沿用）。
  Future<AiConversationOptions> lastOptions() async =>
      AiConversationOptions.decode(
        await database.latestAiConversationOptions(),
      );

  /// 开始一段新对话（进入页面、顶栏“新对话”、删掉了正在看的对话）：范围回到
  /// 自动，人设回到对话的默认，模型与思考强度沿用最近那段对话的选择。
  Future<void> startNew({required String? defaultPersonaId}) async {
    _abandonTurn();
    conversationId = null;
    scope = const AiChatScope.auto();
    personaId = defaultPersonaId;
    _set(AiChatPhase.idle);
    final last = await lastOptions();
    if (_disposed || conversationId != null) return;
    options = last;
    _notify();
  }

  /// “继续聊聊”：新建一段固定在 [reply] 那篇日记上的对话，把回应作为第一条
  /// 回答（标题“关于「某篇」”；没有标题的用日期）。回应不属于某篇日记时只
  /// 准备一段普通的新对话。
  Future<void> seedFromReply(AppLocalizations l10n, AiResultRow reply) async {
    final last = await lastOptions();
    final diaryId = reply.diaryId;
    if (diaryId == null) {
      options = last;
      _notify();
      return;
    }
    final diary = await database.getAiDiary(diaryId);
    final title = (diary?.title.trim().isNotEmpty ?? false)
        ? diary!.title.trim()
        : (diary == null
              ? ''
              : DateFormat.yMMMd(l10n.localeName).format(diary.createdAt));
    final fixed = AiChatScope.diary(diaryId: diaryId, diaryTitle: title);
    final id = await database.createAiConversation(
      title: title.isEmpty ? '' : l10n.aiChatAboutEntry(title),
      personaId: reply.personaId,
      scopeJson: fixed.encode(),
      optionsJson: last.encode(),
    );
    await database.addAiMessage(
      conversationId: id,
      role: AiMessageRole.assistant,
      content: reply.content,
      metaJson: reply.meta,
    );
    if (_disposed) return;
    conversationId = id;
    scope = fixed;
    personaId = reply.personaId;
    options = last;
    _notify();
  }

  /// 放下正在进行的这一轮（换对话时）：与离开页面同一口径保存已有的部分，
  /// 旧的异步回调经世代号作废。
  void _abandonTurn() {
    _savePartialAsStopped();
    _generation++;
    _planToken?.cancel();
    _planToken = null;
    _titleToken?.cancel();
    _autoOpen = null;
    run.reset();
  }

  /// 正在生成的检索回答按“已停止”保存；智能体的这一轮停掉并写完。
  void _savePartialAsStopped() {
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
    final turn = _agentTurn;
    if (turn != null) {
      _agentToken?.cancel();
      _agentToken = null;
      _agentTurn = null;
      unawaited(turn.stop().whenComplete(turn.dispose));
    }
  }

  /// 停止检索计划或回答（回答已收到的部分会保存）。
  void stop() {
    _planToken?.cancel();
    _planToken = null;
    _titleToken?.cancel();
    _agentToken?.cancel();
    run.stop();
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
      if (options.thinking case final level?) 'thinking': level.name,
      if (run.thinking.elapsedMs > 0) 'thinkingMs': run.thinking.elapsedMs,
      if (usage != null) ...usage.toMeta(),
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
    // 页面没了照样能写）；智能体的步骤边做边落库，停掉这一轮把已有的文字
    // 按“已停止”写完。
    _savePartialAsStopped();
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
