// 智能体回答的工具步骤（存进 `ai_messages.steps` 的 JSON）。
//
// 一条回答 = 若干步骤 + 最后的正文（`content`）。每一步是模型的一次请求：
// 它在调用工具前说的话（[AiAgentStepRecord.text]）与这一步的调用记录。
// 调用记录是参数、状态与结果摘要的唯一来源（借鉴 Phase 的
// ToolCallRecord）：派发前先记成 [AiToolCallStatus.executing] 落库，结果出来
// 再更新；重开对话时 executing 且不在进行中的按“已中断”显示，绝不重放。
//
// 编解码逐字段容错：认不出的状态按已中断，坏掉的整步丢掉，不影响正文。
//
// 下一轮原样回放（`ai_agent_history.dart`）要用的也记在这里：每一步模型的
// 原始正文（[AiAgentStepRecord.text] 不做清理，显示时才 trim）与协议回放
// 数据（[AiAgentStepRecord.replay]，如 DeepSeek 的 `reasoning_content`），
// 每个调用回传给模型的结果原文（[AiAgentCallRecord.result]）。回放的内容与
// 当时发出去的逐字一致，服务商的前缀缓存才能命中。

import 'dart:convert';

import 'package:meta/meta.dart';

import '../../../core/services/ai/ai_models.dart';
import '../tools/ai_tool.dart';
import 'ai_tool_subject.dart';

/// 参数不是 JSON 对象时，调用记录里保存原文用的键（[AiAgentCallRecord.args]
/// 里只有这一项）。回放时据此按“参数无效”的调用带回。
const String kAiRawArgumentsKey = '_raw';

/// 一个调用的状态。
enum AiToolCallStatus {
  /// 已派发、还没有结果（不在进行中时按已中断显示）。
  executing,

  /// 等用户确认（只在内存里出现，落库时不会是这个状态）。
  awaitingConfirmation,
  succeeded,
  failed,

  /// 用户拒绝了确认。
  rejected,

  /// 用户停止了这一轮。
  cancelled;

  static AiToolCallStatus parse(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return executing;
  }

  bool get finished => this != executing && this != awaitingConfirmation;
}

@immutable
class AiAgentCallRecord {
  const AiAgentCallRecord({
    required this.id,
    required this.tool,
    required this.args,
    required this.status,
    this.summary,
    this.error,
    this.navigation,
    this.undo,
    this.undone = false,
    this.preview,
    this.subjects = const <AiToolSubject>[],
    this.moreSubjects = 0,
    this.result,
    this.resultIsError = false,
    this.providerData,
    this.idFromProvider = true,
    this.images = const <AiAgentImageRecord>[],
  });

  final String id;

  /// 工具名（[AiTool.name]）。
  final String tool;

  /// 模型给的原始参数（卡片标题按它生成）。
  final Map<String, Object?> args;
  final AiToolCallStatus status;

  /// 结果的简短说明（界面语言，执行时生成）。
  final String? summary;

  /// 失败原因（回传给模型的同一句，英文）。
  final String? error;

  /// “前往”按钮。
  final AiToolNavigation? navigation;

  /// 撤销所需的数据（写工具给的 [AiToolOutcome.undo]）；交回 [AiTool.undo]。
  final Map<String, Object?>? undo;

  /// 已经撤销过。
  final bool undone;

  /// 等待确认时给用户看的内容（只在内存里，不落库）。
  final AiToolPreview? preview;

  /// 涉及的对象（最多 [AiToolSubject.maxStored] 个，其余记在 [moreSubjects]）。
  final List<AiToolSubject> subjects;
  final int moreSubjects;

  /// 回传给模型的结果原文（成功、失败、被拒都有；旧记录与没有结果的为
  /// null）。下一轮原样回放。
  final String? result;
  final bool resultIsError;

  /// 协议附带在调用上、回放时要原样带回的数据（[AiToolCall.providerData]：
  /// Gemini 的思考签名、Responses 的条目 id）与调用 id 的来源。
  final Map<String, Object?>? providerData;
  final bool idFromProvider;

  /// 结果之后附上的图片（“查看图片”看的），按附上的顺序。回放时按它重新
  /// 读图、放回结果之后；不算存储引用（只是看过哪张，日记里删了图就读成
  /// “读不出来”）。
  final List<AiAgentImageRecord> images;

  /// 能不能撤销：成功了、带着撤销数据、还没撤销过。
  bool get canUndo =>
      status == AiToolCallStatus.succeeded && undo != null && !undone;

  AiAgentCallRecord copyWith({
    AiToolCallStatus? status,
    String? summary,
    String? error,
    AiToolNavigation? navigation,
    Map<String, Object?>? undo,
    bool? undone,
    AiToolPreview? preview,
    List<AiToolSubject>? subjects,
    String? result,
    bool? resultIsError,
    List<AiAgentImageRecord>? images,
  }) {
    final allSubjects = subjects;
    return AiAgentCallRecord(
      id: id,
      tool: tool,
      args: args,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      error: error ?? this.error,
      navigation: navigation ?? this.navigation,
      undo: undo ?? this.undo,
      undone: undone ?? this.undone,
      // 预览只在等确认时有用，状态一变就丢掉。
      preview: status == null || status == AiToolCallStatus.awaitingConfirmation
          ? preview ?? this.preview
          : null,
      subjects: allSubjects == null
          ? this.subjects
          : allSubjects.take(AiToolSubject.maxStored).toList(growable: false),
      moreSubjects: allSubjects == null
          ? moreSubjects
          : (allSubjects.length - AiToolSubject.maxStored).clamp(0, 1 << 30),
      result: result ?? this.result,
      resultIsError: resultIsError ?? this.resultIsError,
      providerData: providerData,
      idFromProvider: idFromProvider,
      images: images ?? this.images,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'tool': tool,
    if (args.isNotEmpty) 'args': args,
    'status': status == AiToolCallStatus.awaitingConfirmation
        ? AiToolCallStatus.executing.name
        : status.name,
    'summary': ?summary,
    'error': ?error,
    if (navigation != null) 'navigation': navigation!.toJson(),
    'undo': ?undo,
    if (undone) 'undone': true,
    if (subjects.isNotEmpty)
      'subjects': [for (final subject in subjects) subject.toJson()],
    if (moreSubjects > 0) 'moreSubjects': moreSubjects,
    'result': ?result,
    if (resultIsError) 'resultError': true,
    'providerData': ?providerData,
    if (!idFromProvider) 'localId': true,
    if (images.isNotEmpty)
      'images': [for (final image in images) image.toJson()],
  };

  static AiAgentCallRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final tool = raw['tool'];
    if (id is! String || tool is! String) return null;
    final args = raw['args'];
    final summary = raw['summary'];
    final error = raw['error'];
    final undo = raw['undo'];
    final subjects = raw['subjects'];
    final more = raw['moreSubjects'];
    final result = raw['result'];
    final providerData = raw['providerData'];
    final images = raw['images'];
    return AiAgentCallRecord(
      id: id,
      tool: tool,
      args: args is Map
          ? args.cast<String, Object?>()
          : const <String, Object?>{},
      status: AiToolCallStatus.parse(raw['status']),
      summary: summary is String ? summary : null,
      error: error is String ? error : null,
      navigation: AiToolNavigation.fromJson(raw['navigation']),
      undo: undo is Map ? undo.cast<String, Object?>() : null,
      undone: raw['undone'] == true,
      subjects: [
        if (subjects is List)
          for (final item in subjects)
            if (AiToolSubject.fromJson(item) case final subject?) subject,
      ],
      moreSubjects: more is int && more > 0 ? more : 0,
      result: result is String ? result : null,
      resultIsError: raw['resultError'] == true,
      providerData: providerData is Map
          ? providerData.cast<String, Object?>()
          : null,
      idFromProvider: raw['localId'] != true,
      images: [
        if (images is List)
          for (final item in images)
            if (AiAgentImageRecord.fromJson(item) case final image?) image,
      ],
    );
  }
}

/// 一次调用结果之后附上的一张图片。
@immutable
class AiAgentImageRecord {
  const AiAgentImageRecord({
    required this.label,
    required this.source,
    this.diaryId,
  });

  /// 给模型看的称呼（`D3#2`、`P1`），回放的占位文字里用它。
  final String label;

  /// 托管图片的绝对路径。
  final String source;

  /// 来自日记时那篇日记的业务 id（回放时重新检查还能不能给 AI 看）。
  final String? diaryId;

  Map<String, Object?> toJson() => <String, Object?>{
    'label': label,
    'source': source,
    'diary': ?diaryId,
  };

  static AiAgentImageRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final label = raw['label'];
    final source = raw['source'];
    final diary = raw['diary'];
    if (label is! String || source is! String || source.isEmpty) return null;
    return AiAgentImageRecord(
      label: label,
      source: source,
      diaryId: diary is String ? diary : null,
    );
  }
}

@immutable
class AiAgentStepRecord {
  const AiAgentStepRecord({
    this.text = '',
    this.reasoning = '',
    this.thinkingMs = 0,
    this.calls = const <AiAgentCallRecord>[],
    this.replay = const <AiReplayPart>[],
  });

  /// 模型在调用工具之前说的话（原文，显示时 trim）。
  final String text;
  final String reasoning;

  /// 这一步要原样带回服务商的协议数据（思考签名、`reasoning_content`
  /// 等），只回放给产生它的同一服务商与模型。
  final List<AiReplayPart> replay;

  /// 这一步的思考时长（毫秒，`AiThinkingClock`；没有思考或旧记录为 0）。
  final int thinkingMs;
  final List<AiAgentCallRecord> calls;

  AiAgentStepRecord withCall(AiAgentCallRecord call) => AiAgentStepRecord(
    text: text,
    reasoning: reasoning,
    thinkingMs: thinkingMs,
    replay: replay,
    calls: [
      for (final existing in calls)
        if (existing.id == call.id) call else existing,
    ],
  );

  Map<String, Object?> toJson() => <String, Object?>{
    if (text.isNotEmpty) 'text': text,
    if (reasoning.isNotEmpty) 'reasoning': reasoning,
    if (thinkingMs > 0) 'thinkingMs': thinkingMs,
    'calls': [for (final call in calls) call.toJson()],
    if (replay.isNotEmpty)
      'replay': [
        for (final part in replay)
          <String, Object?>{'protocol': part.protocol.name, 'data': part.data},
      ],
  };

  static AiAgentStepRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    final reasoning = raw['reasoning'];
    final thinkingMs = raw['thinkingMs'];
    final calls = raw['calls'];
    final replay = raw['replay'];
    return AiAgentStepRecord(
      text: text is String ? text : '',
      reasoning: reasoning is String ? reasoning : '',
      thinkingMs: thinkingMs is int && thinkingMs > 0 ? thinkingMs : 0,
      calls: [
        if (calls is List)
          for (final item in calls)
            if (AiAgentCallRecord.fromJson(item) case final call?) call,
      ],
      replay: [
        if (replay is List)
          for (final item in replay)
            if (item is Map &&
                AiProtocol.fromName(item['protocol']) != null &&
                item['data'] is Map)
              AiReplayPart(
                AiProtocol.fromName(item['protocol'])!,
                (item['data'] as Map).cast<String, Object?>(),
              ),
      ],
    );
  }

  static String encodeList(List<AiAgentStepRecord> steps) =>
      jsonEncode([for (final step in steps) step.toJson()]);

  static List<AiAgentStepRecord> decodeList(String raw) {
    if (raw.isEmpty || raw == '[]') return const <AiAgentStepRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <AiAgentStepRecord>[];
      return [
        for (final item in decoded)
          if (AiAgentStepRecord.fromJson(item) case final step?) step,
      ];
    } on FormatException {
      return const <AiAgentStepRecord>[];
    }
  }
}
