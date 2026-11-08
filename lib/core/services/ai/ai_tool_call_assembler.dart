import 'dart:convert';

import 'ai_models.dart';

/// 把流式响应里零散的工具调用片段拼成完整的 [AiToolCall]，四个协议客户端
/// 共用。
///
/// - 每个调用用协议自己的键区分（Chat 的 `tool_calls[].index`、Anthropic
///   的内容块下标、Responses 的条目 id、Gemini 的顺序号），先到先排；
/// - 参数片段只追加、不在中途解析（半截 JSON 解析不了，也不该据此行动）；
///   服务端给出完整快照时用 [add] 的 `replaceArguments` 覆盖；
/// - [finish] 在流结束后一次性解析：参数不是 JSON 对象的调用照样返回，但
///   带着 [AiToolCall.argumentsError]，由调用方把错误回传模型而不是执行；
/// - 服务商没给 id、或同一响应里 id 重复时生成本地 id（旧版 Gemini 会
///   重复给 `tool_0` 之类），保证结果能一一配对。
class AiToolCallAssembler {
  final Map<Object, _PendingCall> _pending = <Object, _PendingCall>{};

  bool get isEmpty => _pending.isEmpty;

  /// 收到属于 [key] 的一段数据。第一次见到这个键且已知名称时返回
  /// [AiToolCallStart]（供界面提示），其余情况返回 null。
  AiToolCallStart? add(
    Object key, {
    String? id,
    String? name,
    String? arguments,
    bool replaceArguments = false,
    Map<String, Object?>? providerData,
  }) {
    final call = _pending.putIfAbsent(key, _PendingCall.new);
    final announcedBefore = call.announced;
    if (id != null && id.isNotEmpty) call.id = id;
    if (name != null && name.isNotEmpty) call.name = name;
    if (arguments != null) {
      if (replaceArguments) call.arguments.clear();
      call.arguments.write(arguments);
    }
    if (providerData != null && providerData.isNotEmpty) {
      call.providerData = <String, Object?>{
        ...?call.providerData,
        ...providerData,
      };
    }
    if (!announcedBefore && call.name.isNotEmpty) {
      call.announced = true;
      return AiToolCallStart(index: _indexOf(key), name: call.name);
    }
    return null;
  }

  int _indexOf(Object key) {
    var index = 0;
    for (final existing in _pending.keys) {
      if (existing == key) return index;
      index++;
    }
    return index;
  }

  /// 流结束后取出全部调用（按出现顺序）。没有名称的残片丢弃。
  List<AiToolCall> finish() {
    final calls = <AiToolCall>[];
    final usedIds = <String>{};
    var local = 0;
    for (final pending in _pending.values) {
      if (pending.name.isEmpty) continue;
      var id = pending.id;
      var fromProvider = true;
      if (id.isEmpty || usedIds.contains(id)) {
        do {
          id = 'call_${_localPrefix}_${local++}';
        } while (usedIds.contains(id));
        fromProvider = false;
      }
      usedIds.add(id);
      calls.add(
        parseAiToolCall(
          id: id,
          name: pending.name,
          argumentsRaw: pending.arguments.toString(),
          idFromProvider: fromProvider,
          providerData: pending.providerData,
        ),
      );
    }
    return calls;
  }

  /// 每次运行不同的前缀，免得本地 id 与以前各步的撞上。
  static final String _localPrefix = DateTime.now().microsecondsSinceEpoch
      .toRadixString(36);
}

class _PendingCall {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
  Map<String, Object?>? providerData;
  bool announced = false;
}

/// 解析一个完整调用的参数原文。空白参数视为 `{}`（不少模型对无参工具
/// 不输出任何参数）；Gemini 等直接给出对象时用 [encodeAiToolArguments]
/// 先编成原文。
AiToolCall parseAiToolCall({
  required String id,
  required String name,
  required String argumentsRaw,
  bool idFromProvider = true,
  Map<String, Object?>? providerData,
}) {
  final raw = argumentsRaw.trim();
  Map<String, Object?>? arguments;
  String? error;
  if (raw.isEmpty) {
    arguments = <String, Object?>{};
  } else {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        arguments = decoded.cast<String, Object?>();
      } else {
        error = 'Arguments must be a JSON object.';
      }
    } on FormatException catch (exception) {
      error = 'Arguments are not valid JSON: ${exception.message}';
    }
  }
  return AiToolCall(
    id: id,
    name: name,
    argumentsRaw: argumentsRaw,
    arguments: arguments,
    argumentsError: error,
    idFromProvider: idFromProvider,
    providerData: providerData,
  );
}

/// 把对象形式的参数编成原文（Gemini 的 `functionCall.args`、Anthropic
/// 块开始时就带着的 `input`）。
String encodeAiToolArguments(Object? arguments) {
  if (arguments == null) return '';
  if (arguments is Map && arguments.isEmpty) return '';
  return jsonEncode(arguments);
}
