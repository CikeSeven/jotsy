// 智能体的一轮：实现 `AiAgentHost`，把循环的每一步落库、显示、执行。
//
// 落库（借鉴 Phase 的“派发前落库、中断不重放”）：
// - 开始时就建好助手消息行（状态 stopped，内容为空）：进程被杀也能看到已经
//   执行过的步骤；
// - 每一步的输出收齐后写入步骤（调用记为 executing），每个调用出结果后再写；
//   写库串行排队，后写的不会被先写的覆盖；
// - 结束时写正文、引用、用量与状态（[complete] / [fail] / [stop]）。
//
// 执行一个调用：找工具 → 参数是坏 JSON 时直接回传错误 → 经 schema 集中校验
// 与转换 → 执行 → 结果统一经 `aiToolResultText` 限长。失败都作为
// `isError` 结果回传模型（让它改正或换个做法），不抛出；只有停止时抛
// cancelled。同一步的多个调用由循环串行调用这里。
//
// 界面：本类是 ChangeNotifier，流式文字与步骤变化时通知（文字增量节流到
// 50ms 一次，免得长回答每个字都重排 Markdown）。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_agent_loop.dart';
import '../../../core/services/ai/agent/ai_tool_result.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/ai/ai_failure.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/editing_session_registry.dart';
import '../models/ai_agent_steps.dart';
import '../tools/ai_tool.dart';
import '../tools/ai_tool_registry.dart';
import '../viewmodels/ai_citations.dart';
import '../viewmodels/ai_task_prompts.dart';
import 'ai_stream_run.dart';
import 'ai_thinking_clock.dart';

class AiAgentTurn extends ChangeNotifier implements AiAgentHost {
  AiAgentTurn({
    required this.database,
    required this.conversationId,
    required this.model,
    required this.tools,
    required this.toolContext,
    this.thinkingLevel,
  });

  final AppDatabase database;
  final String conversationId;
  final AiResolvedModel model;
  final Map<String, AiTool> tools;
  final AiToolContext toolContext;

  /// 这一轮请求的思考强度（记进 meta，回答底部显示）；null 为自动。
  final AiThinkingLevel? thinkingLevel;

  /// 当前这一步的思考计时（每步收齐后清零，时长记进步骤）。
  final AiThinkingClock thinking = AiThinkingClock();

  /// 已收齐的工具步骤（正在执行的那一步也在里面）。
  final List<AiAgentStepRecord> steps = <AiAgentStepRecord>[];

  /// 当前这一步正在流式输出的正文与思考。
  String text = '';
  String reasoning = '';

  /// 当前这一步模型正在准备的工具调用（界面提示）。
  String? preparingTool;

  /// 本轮的助手消息行（[begin] 之后才有）。
  String? messageId;

  /// 本轮要自动打开的页面（用户明确说“打开…”）。
  AiToolNavigation? autoOpen;

  AiUsage? _usage;
  final Map<String, Completer<bool>> _decisions = <String, Completer<bool>>{};
  Future<void> _writes = Future<void>.value();
  Timer? _notifyTimer;
  bool _disposed = false;

  bool get hasOutput => steps.isNotEmpty || text.isNotEmpty;

  /// 建好助手消息行。
  Future<void> begin() async {
    messageId = await database.addAiMessage(
      conversationId: conversationId,
      role: AiMessageRole.assistant,
      content: '',
      metaJson: _meta(),
      status: AiMessageStatus.stopped,
    );
  }

  // ------------------------------------------------------------ AiAgentHost

  @override
  void onDelta(int step, AiChunk chunk) {
    text += chunk.text;
    reasoning += chunk.reasoning;
    thinking.onDelta(
      reasoning: chunk.reasoning.isNotEmpty,
      output: chunk.text.isNotEmpty || chunk.toolCallStarted != null,
    );
    if (chunk.toolCallStarted case final started?) {
      preparingTool = started.name;
      _notifyNow();
      return;
    }
    if (chunk.text.isNotEmpty || chunk.reasoning.isNotEmpty) _notifySoon();
  }

  @override
  Future<void> onStepOutput(int step, AiAgentStepOutput output) async {
    if (output.usage case final usage?) {
      _usage = _usage == null ? usage : _usage! + usage;
    }
    thinking.stop();
    final thinkingMs = thinking.elapsedMs;
    thinking.reset();
    steps.add(
      AiAgentStepRecord(
        // 原文照存：下一轮原样回放，与这一步发回模型的逐字一致。
        text: output.text,
        reasoning: output.reasoning,
        thinkingMs: thinkingMs,
        replay: output.replay,
        calls: [
          for (final call in output.calls)
            AiAgentCallRecord(
              id: call.id,
              tool: call.name,
              args:
                  call.arguments ??
                  <String, Object?>{kAiRawArgumentsKey: call.argumentsRaw},
              status: AiToolCallStatus.executing,
              providerData: call.providerData,
              idFromProvider: call.idFromProvider,
            ),
        ],
      ),
    );
    text = '';
    reasoning = '';
    preparingTool = null;
    _notifyNow();
    await _save();
  }

  @override
  Future<AiToolResultPart> execute(int step, AiToolCall call) async {
    final tool = tools[call.name];
    if (tool == null) {
      return _fail(step, call, 'Unknown tool `${call.name}`.');
    }
    final raw = call.arguments;
    if (raw == null) {
      return _fail(step, call, call.argumentsError ?? 'Invalid arguments.');
    }
    final Map<String, Object?> args;
    try {
      args = tool.schema.validate(raw);
    } on AiToolArgumentError catch (error) {
      return _fail(step, call, error.message);
    }
    final changes = aiToolChangesData(tool);
    final registry = EditingSessionRegistry.instance;
    // 编辑页整份保存会盖掉这里的改动：有页面在编辑时不写。
    if (changes && registry.isEditing) {
      return _fail(
        step,
        call,
        'Another page is editing data (${registry.activeEditorLabels.join(', ')}). '
        'Ask the user to close it, then try again.',
        summary: toolContext.l10n.aiToolBlockedByEditor,
      );
    }
    final confirm =
        tool.effect == AiToolEffect.destructive ||
        (tool.effect == AiToolEffect.write &&
            toolContext.prefs.agent.confirmChanges);
    if (confirm) {
      final AiToolPreview? preview;
      try {
        preview = await tool.preview(toolContext, args);
      } on AiToolFailure catch (failure) {
        return _fail(step, call, failure.message, summary: failure.summary);
      }
      _update(
        step,
        call.id,
        (record) => record.copyWith(
          status: AiToolCallStatus.awaitingConfirmation,
          preview:
              preview ??
              AiToolPreview(title: tool.label(toolContext.l10n, raw)),
        ),
      );
      final approved = await _awaitDecision(call.id);
      if (!approved) {
        final content = jsonEncode(<String, Object?>{
          'error':
              'The user declined this action. Do not try to get the same '
              'effect another way; ask what they want instead.',
        });
        _update(
          step,
          call.id,
          (record) => record.copyWith(
            status: AiToolCallStatus.rejected,
            result: content,
            resultIsError: true,
          ),
        );
        await _save();
        return AiToolResultPart(
          callId: call.id,
          name: call.name,
          content: content,
          isError: true,
        );
      }
      _update(
        step,
        call.id,
        (record) => record.copyWith(status: AiToolCallStatus.executing),
      );
    }
    final lease = changes ? registry.beginEditing('ai-agent') : null;
    try {
      final outcome = await tool.run(toolContext, args);
      if (toolContext.token.isCancelled) throw const _Cancelled();
      final content = aiToolResultText(outcome.data);
      _update(
        step,
        call.id,
        (record) => record.copyWith(
          status: AiToolCallStatus.succeeded,
          summary: outcome.summary,
          navigation: outcome.navigation,
          undo: outcome.undo,
          subjects: outcome.subjects,
          result: content,
        ),
      );
      if (outcome.navigation case final navigation? when navigation.now) {
        autoOpen = navigation;
      }
      await _save();
      return AiToolResultPart(
        callId: call.id,
        name: call.name,
        content: content,
      );
    } on AiToolFailure catch (failure) {
      return _fail(step, call, failure.message, summary: failure.summary);
    } on _Cancelled {
      _update(
        step,
        call.id,
        (record) => record.copyWith(status: AiToolCallStatus.cancelled),
      );
      await _save();
      throw const AiException(AiFailureKind.cancelled);
    } catch (error) {
      // 工具里的意外错误（数据库、解析）：如实回传，模型可以换个做法。
      return _fail(step, call, 'The tool failed: $error');
    } finally {
      lease?.end();
    }
  }

  /// 等用户在确认卡上点“执行 / 取消”（[decide]）；停止时当作取消并抛出。
  Future<bool> _awaitDecision(String callId) async {
    final completer = _decisions[callId] = Completer<bool>();
    final token = toolContext.token;
    final decided = await Future.any<bool?>(<Future<bool?>>[
      completer.future,
      token.whenCancelled.then((_) => null),
    ]);
    _decisions.remove(callId);
    if (decided == null || token.isCancelled) throw const _Cancelled();
    return decided;
  }

  /// 用户对某个等待确认的调用做了决定。
  void decide(String callId, {required bool approved}) {
    final completer = _decisions[callId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(approved);
    }
  }

  Future<AiToolResultPart> _fail(
    int step,
    AiToolCall call,
    String message, {
    String? summary,
  }) async {
    final content = jsonEncode(<String, Object?>{'error': message});
    _update(
      step,
      call.id,
      (record) => record.copyWith(
        status: AiToolCallStatus.failed,
        error: message,
        summary: summary,
        result: content,
        resultIsError: true,
      ),
    );
    await _save();
    return AiToolResultPart(
      callId: call.id,
      name: call.name,
      content: content,
      isError: true,
    );
  }

  void _update(
    int step,
    String callId,
    AiAgentCallRecord Function(AiAgentCallRecord record) change,
  ) {
    if (step >= steps.length) return;
    final current = steps[step];
    final record = current.calls.where((c) => c.id == callId).firstOrNull;
    if (record == null) return;
    steps[step] = current.withCall(change(record));
    _notifyNow();
  }

  // ------------------------------------------------------------ 收尾

  /// 正常结束：写正文、引用、用量。
  Future<void> complete(AiAgentResult result) async {
    if (result.usage case final usage?) _usage = usage;
    text = aiCleanOutput(result.text);
    reasoning = result.reasoning;
    await _finish(
      AiMessageStatus.done,
      extra: <String, Object?>{
        if (result.end != AiAgentEnd.answered) 'agentEnd': result.end.name,
      },
    );
  }

  /// 出错：保留已有的步骤与文字，记下原因。
  Future<void> fail(Object error) async {
    final failure = error is AiException ? error : null;
    _cancelRunning();
    await _finish(
      AiMessageStatus.error,
      extra: <String, Object?>{
        'errorKind': (failure?.kind ?? AiFailureKind.badResponse).name,
        if (failure?.statusCode case final code?) 'statusCode': code,
        'errorDetail': failure?.providerMessage ?? failure?.detail ?? '$error',
      },
    );
  }

  /// 停止（含离开页面）：保留已有的步骤与文字。
  Future<void> stop() async {
    _cancelRunning();
    await _finish(AiMessageStatus.stopped);
  }

  /// 换成检索问答前删掉占位的消息行（一个字、一步都还没有时才会这样做）。
  Future<void> discard() async {
    final id = messageId;
    if (id == null) return;
    await _writes;
    await database.deleteAiMessages([id]);
    messageId = null;
  }

  void _cancelRunning() {
    for (var i = 0; i < steps.length; i++) {
      for (final call in steps[i].calls) {
        if (!call.status.finished) {
          steps[i] = steps[i].withCall(
            call.copyWith(status: AiToolCallStatus.cancelled),
          );
        }
      }
    }
  }

  Future<void> _finish(
    String status, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    preparingTool = null;
    thinking.stop();
    final id = messageId;
    if (id == null) return;
    final content = text;
    final citations = cited();
    final stepsJson = AiAgentStepRecord.encodeList(steps);
    final metaJson = _meta(extra: extra);
    final reasoningText = reasoning;
    _writes = _writes.then(
      (_) => database.updateAiMessage(
        id,
        content: content,
        reasoning: reasoningText,
        citationsJson: AiCitation.encodeList(citations),
        metaJson: metaJson,
        status: status,
        stepsJson: stepsJson,
      ),
    );
    await _writes;
    _notifyNow();
  }

  /// 回答与步骤说明里真的用到的引用。
  List<AiCitation> cited() {
    final refs = <String>{
      ...aiCitedRefs(text),
      for (final step in steps) ...aiCitedRefs(step.text),
    };
    return [
      for (final citation in toolContext.citations.all)
        if (refs.contains(citation.ref)) citation,
    ];
  }

  Future<void> _save() {
    final id = messageId;
    if (id == null) return Future<void>.value();
    final stepsJson = AiAgentStepRecord.encodeList(steps);
    final metaJson = _meta();
    _writes = _writes.then(
      (_) => database.updateAiMessage(
        id,
        stepsJson: stepsJson,
        metaJson: metaJson,
      ),
    );
    return _writes;
  }

  String _meta({Map<String, Object?> extra = const <String, Object?>{}}) {
    final usage = _usage;
    return jsonEncode(<String, Object?>{
      'provider': model.provider.name,
      // 下一轮回放时据此判断协议回放数据（思考签名等）能不能带回去。
      'providerId': model.provider.id,
      'model': model.model.id,
      'agent': true,
      // 本轮工具读到过的日记篇数（“参考了 N 篇”里没被引用的也算）。
      'contextEntries': toolContext.citations.length,
      // 本轮新分配的引用编号（下一轮接着编；有这一项也表示步骤里存着结果
      // 原文，可以原样回放）。
      'refs': [
        for (final citation in toolContext.citations.fresh) citation.toJson(),
      ],
      if (thinkingLevel != null) 'thinking': thinkingLevel!.name,
      // 最后一段（作答这一步）的思考时长；各工具步骤的记在步骤里。
      if (thinking.elapsedMs > 0) 'thinkingMs': thinking.elapsedMs,
      if (usage != null) ...usage.toMeta(),
      ...extra,
    });
  }

  // ------------------------------------------------------------ 通知

  void _notifySoon() {
    if (_notifyTimer?.isActive ?? false) return;
    _notifyTimer = Timer(const Duration(milliseconds: 50), _notifyNow);
  }

  void _notifyNow() {
    _notifyTimer?.cancel();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    super.dispose();
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
