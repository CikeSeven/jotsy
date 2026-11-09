import 'dart:typed_data';

import 'package:meta/meta.dart';

part 'ai_models_tools.dart';

/// AI 服务的接口协议。三种协议覆盖绝大多数服务商：
/// - [openAi]：OpenAI Chat Completions 兼容格式（DeepSeek、通义、Kimi、智谱、
///   豆包、硅基流动、OpenRouter、Ollama、LM Studio 等）；
/// - [anthropic]：Anthropic Messages API（Claude，及提供同格式的转发服务）；
/// - [gemini]：Google Gemini `generateContent`。
enum AiProtocol {
  /// OpenAI Chat Completions 兼容接口（绝大多数服务商）。
  openAi,

  /// OpenAI Responses API（`/responses`，OpenAI 现行的主接口）。
  openAiResponses,
  anthropic,
  gemini;

  static AiProtocol? fromName(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// 对话中的角色。系统提示词单独放在 [AiRequest.system]，不进消息列表。
enum AiRole { user, assistant }

/// 一条消息里的一段内容：文字或图片。
@immutable
sealed class AiPart {
  const AiPart();
}

@immutable
class AiTextPart extends AiPart {
  const AiTextPart(this.text);

  final String text;
}

/// 图片原始字节与 MIME（`image/png`、`image/jpeg` 等），由客户端按协议
/// 编成 base64。
@immutable
class AiImagePart extends AiPart {
  const AiImagePart(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

@immutable
class AiMessage {
  const AiMessage(this.role, this.parts);

  AiMessage.text(this.role, String text) : parts = <AiPart>[AiTextPart(text)];

  final AiRole role;
  final List<AiPart> parts;

  String get text =>
      parts.whereType<AiTextPart>().map((part) => part.text).join('\n');

  bool get hasImages => parts.any((part) => part is AiImagePart);

  /// 这条消息里的工具调用（助手消息）。
  Iterable<AiToolCall> get toolCalls =>
      parts.whereType<AiToolCallPart>().map((part) => part.call);

  /// 这条消息里的工具结果（用户消息）。
  Iterable<AiToolResultPart> get toolResults =>
      parts.whereType<AiToolResultPart>();

  /// 某种协议留下的不透明回放数据（思考签名、加密推理等）。
  Iterable<AiReplayPart> replayFor(AiProtocol protocol) => parts
      .whereType<AiReplayPart>()
      .where((part) => part.protocol == protocol);
}

/// 思考强度（对话页“模型与思考”面板）。null 表示“自动”：不发任何强度
/// 参数，由模型自己决定（与加入强度之前的请求完全一样）。
///
/// 各协议的写法见各客户端的 `buildBody`：OpenAI Chat 为 `reasoning_effort`，
/// Responses 为 `reasoning.effort`，Anthropic 为 `output_config.effort`（关为
/// `thinking.type: disabled`），Gemini 为 `thinkingLevel`（关为
/// `thinkingBudget: 0`）。服务端不认强度参数（400）时 `AiService` 去掉强度
/// 重试一次并在本次运行内记住，见 `AiService.stream`。
enum AiThinkingLevel {
  /// 明确关掉思考：直接回答，最快。
  off,
  low,
  medium,
  high;

  static AiThinkingLevel? parse(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// 一次生成请求。协议差异（必填的 `max_tokens`、采样参数是否发送、思考
/// 开关的写法）由各客户端按服务商配置处理，这里只描述意图。
@immutable
class AiRequest {
  const AiRequest({
    required this.model,
    required this.messages,
    this.system,
    this.temperature,
    this.maxOutputTokens,
    this.reasoning = false,
    this.thinking,
    this.tools = const <AiToolSpec>[],
    this.toolChoice = AiToolChoice.auto,
    this.cacheKey,
  });

  final String model;
  final String? system;
  final List<AiMessage> messages;

  /// 期望的温度；null 表示不发送，由服务端用默认值。
  final double? temperature;

  /// 最多生成多少 token；null 时按协议的默认值（Anthropic 必填）。
  final int? maxOutputTokens;

  /// 请服务端返回思考过程（支持的模型才生效）。
  final bool reasoning;

  /// 思考强度；null 为自动（不发强度参数）。为 [AiThinkingLevel.off] 时
  /// [reasoning] 一定为 false（`AiService.prepareRequest` 保证）。
  final AiThinkingLevel? thinking;

  /// 模型可以调用的工具；为空时请求里不带任何工具字段。
  final List<AiToolSpec> tools;

  /// 是否允许模型调用 [tools]。
  final AiToolChoice toolChoice;

  /// 提示缓存的会话键（智能体为对话 id）。给出时表示后续请求会以这次的
  /// 消息为前缀继续，各客户端据此打开显式缓存：Anthropic 打 `cache_control`
  /// 断点（写缓存要多计费，一次性请求不打），OpenAI 发 `prompt_cache_key`
  /// 让同一对话落到同一缓存。DeepSeek、Gemini 等自动前缀缓存不需要。
  final String? cacheKey;

  AiRequest copyWith({
    String? model,
    String? system,
    List<AiMessage>? messages,
    double? temperature,
    int? maxOutputTokens,
    bool? reasoning,
    List<AiToolSpec>? tools,
    AiToolChoice? toolChoice,
  }) {
    return AiRequest(
      model: model ?? this.model,
      system: system ?? this.system,
      messages: messages ?? this.messages,
      temperature: temperature ?? this.temperature,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      reasoning: reasoning ?? this.reasoning,
      thinking: thinking,
      tools: tools ?? this.tools,
      toolChoice: toolChoice ?? this.toolChoice,
      cacheKey: cacheKey,
    );
  }

  /// 换一个思考强度（可以换成 null，即“自动”）。
  AiRequest withThinking(AiThinkingLevel? level) => AiRequest(
    model: model,
    system: system,
    messages: messages,
    temperature: temperature,
    maxOutputTokens: maxOutputTokens,
    reasoning: level == AiThinkingLevel.off ? false : reasoning,
    thinking: level,
    tools: tools,
    toolChoice: toolChoice,
    cacheKey: cacheKey,
  );

  bool get hasImages => messages.any((message) => message.hasImages);

  bool get hasTools => tools.isNotEmpty;
}

/// 一次请求消耗的 token。部分服务商不返回用量。
///
/// [inputTokens] 是这次读入的全部输入（含命中缓存的部分），
/// [cachedInputTokens] 是其中命中提示缓存、按缓存价计费的部分（各协议的
/// 写法统一到这里：Chat 兼容为 `prompt_tokens_details.cached_tokens` 或
/// DeepSeek 的 `prompt_cache_hit_tokens`，Responses 为
/// `input_tokens_details.cached_tokens`，Anthropic 为
/// `cache_read_input_tokens`，Gemini 为 `cachedContentTokenCount`）。
@immutable
class AiUsage {
  const AiUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedInputTokens = 0,
  });

  final int inputTokens;
  final int outputTokens;
  final int cachedInputTokens;

  int get totalTokens => inputTokens + outputTokens;

  /// 没命中缓存、按原价计费的输入。
  int get uncachedInputTokens =>
      inputTokens > cachedInputTokens ? inputTokens - cachedInputTokens : 0;

  AiUsage operator +(AiUsage other) => AiUsage(
    inputTokens: inputTokens + other.inputTokens,
    outputTokens: outputTokens + other.outputTokens,
    cachedInputTokens: cachedInputTokens + other.cachedInputTokens,
  );

  /// 两份用量取各项较大者：流式响应里用量常分几次给出（如 Anthropic 先在
  /// message_start 给输入、末尾给输出；OpenAI 兼容服务有的每块都带累计值），
  /// 合并后只增不减，不会重复累加。
  AiUsage merge(AiUsage other) => AiUsage(
    inputTokens: other.inputTokens > inputTokens
        ? other.inputTokens
        : inputTokens,
    outputTokens: other.outputTokens > outputTokens
        ? other.outputTokens
        : outputTokens,
    cachedInputTokens: other.cachedInputTokens > cachedInputTokens
        ? other.cachedInputTokens
        : cachedInputTokens,
  );

  /// 记进消息 / 结果 meta 的写法（界面底部的用量从这里读）。
  Map<String, Object?> toMeta() => <String, Object?>{
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    if (cachedInputTokens > 0) 'cachedTokens': cachedInputTokens,
  };

  @override
  bool operator ==(Object other) =>
      other is AiUsage &&
      other.inputTokens == inputTokens &&
      other.outputTokens == outputTokens &&
      other.cachedInputTokens == cachedInputTokens;

  @override
  int get hashCode => Object.hash(inputTokens, outputTokens, cachedInputTokens);

  @override
  String toString() =>
      'AiUsage($inputTokens in ($cachedInputTokens cached), '
      '$outputTokens out)';
}

/// 结束原因，统一四种协议的写法。
enum AiFinishReason {
  /// 正常结束。
  stop,

  /// 正常结束，并且要求调用工具（[AiChunk.toolCalls] 里是完整的调用）。
  toolCalls,

  /// 达到最大输出长度被截断。
  length,

  /// 被服务端的安全策略拦下。
  filtered,

  /// 其他或未知。
  other;

  /// 协议按正常方式收尾。只有这时才能执行工具调用：截断、流中断（没有
  /// 结束原因）或服务端标为未完成的响应里，工具参数可能是半截的。
  bool get isComplete => this == stop || this == toolCalls;
}

/// 流式响应的一块。一块里可以同时带正文增量、思考增量与用量。
///
/// 工具调用不按片段吐出：参数片段由客户端拼好，流结束后在最后一块里给出
/// 完整的 [toolCalls]（见 `AiToolCallAssembler`）；中途只用
/// [toolCallStarted] 告诉界面“开始准备某个调用”。
@immutable
class AiChunk {
  const AiChunk({
    this.text = '',
    this.reasoning = '',
    this.usage,
    this.finishReason,
    this.toolCalls = const <AiToolCall>[],
    this.toolCallStarted,
    this.replay = const <AiReplayPart>[],
  });

  final String text;
  final String reasoning;
  final AiUsage? usage;
  final AiFinishReason? finishReason;

  /// 拼好的完整工具调用（只出现在流的最后）。
  final List<AiToolCall> toolCalls;

  /// 某个工具调用开始生成（只用于界面提示，不能据此执行）。
  final AiToolCallStart? toolCallStarted;

  /// 要原样放回下一步请求的协议数据（见 [AiReplayPart]）。
  final List<AiReplayPart> replay;

  bool get isEmpty =>
      text.isEmpty &&
      reasoning.isEmpty &&
      usage == null &&
      finishReason == null &&
      toolCalls.isEmpty &&
      toolCallStarted == null &&
      replay.isEmpty;
}

/// 拉取模型列表得到的一项。
@immutable
class AiRemoteModel {
  const AiRemoteModel({
    required this.id,
    this.displayName,
    this.contextWindow,
    this.maxOutputTokens,
    this.supportsVision,
  });

  final String id;
  final String? displayName;
  final int? contextWindow;
  final int? maxOutputTokens;

  /// 服务端明确告知的视觉能力；不告知时为 null，由名称推断。
  final bool? supportsVision;
}

/// 一次完整生成的结果（把流拼起来）。
@immutable
class AiCompletion {
  const AiCompletion({
    required this.text,
    this.reasoning = '',
    this.usage,
    this.finishReason,
    this.toolCalls = const <AiToolCall>[],
    this.replay = const <AiReplayPart>[],
  });

  final String text;
  final String reasoning;
  final AiUsage? usage;
  final AiFinishReason? finishReason;
  final List<AiToolCall> toolCalls;
  final List<AiReplayPart> replay;
}
