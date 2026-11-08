// 智能体回答的工具步骤（存进 `ai_messages.steps` 的 JSON）。
//
// 一条回答 = 若干步骤 + 最后的正文（`content`）。每一步是模型的一次请求：
// 它在调用工具前说的话（[AiAgentStepRecord.text]）与这一步的调用记录。
// 调用记录是参数、状态与结果摘要的唯一来源（借鉴 Phase 的
// ToolCallRecord）：派发前先记成 [AiToolCallStatus.executing] 落库，结果出来
// 再更新；重开对话时 executing 且不在进行中的按“已中断”显示，绝不重放。
//
// 编解码逐字段容错：认不出的状态按已中断，坏掉的整步丢掉，不影响正文。

import 'dart:convert';

import 'package:meta/meta.dart';

import '../tools/ai_tool.dart';

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
  }) {
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
    );
  }
}

@immutable
class AiAgentStepRecord {
  const AiAgentStepRecord({
    this.text = '',
    this.reasoning = '',
    this.calls = const <AiAgentCallRecord>[],
  });

  /// 模型在调用工具之前说的话。
  final String text;
  final String reasoning;
  final List<AiAgentCallRecord> calls;

  AiAgentStepRecord withCall(AiAgentCallRecord call) => AiAgentStepRecord(
    text: text,
    reasoning: reasoning,
    calls: [
      for (final existing in calls)
        if (existing.id == call.id) call else existing,
    ],
  );

  Map<String, Object?> toJson() => <String, Object?>{
    if (text.isNotEmpty) 'text': text,
    if (reasoning.isNotEmpty) 'reasoning': reasoning,
    'calls': [for (final call in calls) call.toJson()],
  };

  static AiAgentStepRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    final reasoning = raw['reasoning'];
    final calls = raw['calls'];
    return AiAgentStepRecord(
      text: text is String ? text : '',
      reasoning: reasoning is String ? reasoning : '',
      calls: [
        if (calls is List)
          for (final item in calls)
            if (AiAgentCallRecord.fromJson(item) case final call?) call,
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
