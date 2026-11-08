part of 'ai_models.dart';

// 工具调用的消息模型（与协议无关）。
//
// 一步工具调用在消息列表里的样子：
// - 助手消息：可选的 [AiReplayPart]（思考签名等）、正文、若干 [AiToolCallPart]；
// - 紧接着一条用户消息：与每个调用一一对应的 [AiToolResultPart]。
// 四个协议客户端各自把它编成 Chat 的 `tool_calls` / `role: tool`、Responses
// 的 `function_call` / `function_call_output`、Anthropic 的 `tool_use` /
// `tool_result`、Gemini 的 `functionCall` / `functionResponse`。

/// 一个可供模型调用的工具。[parameters] 是 JSON Schema，只用四家都认的
/// 子集（type / properties / required / enum / items / description /
/// minimum / maximum），Gemini 不认 `additionalProperties`、`oneOf` 等。
@immutable
class AiToolSpec {
  const AiToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });

  /// 只含字母、数字、下划线（四家共同接受的写法），全局唯一。
  final String name;
  final String description;
  final Map<String, Object?> parameters;
}

/// 模型能否调用工具。
enum AiToolChoice {
  /// 由模型决定。
  auto,

  /// 这一步不许调用（工具定义照发，便于服务端复用提示缓存）。
  none,
}

/// 模型发起的一次工具调用（参数已在流结束后整体解析）。
@immutable
class AiToolCall {
  const AiToolCall({
    required this.id,
    required this.name,
    required this.argumentsRaw,
    this.arguments,
    this.argumentsError,
    this.idFromProvider = true,
    this.providerData,
  });

  /// 调用 id，结果按它配对。服务商没给或重复时由客户端生成本地 id。
  final String id;

  /// [id] 是不是服务商给的。Gemini 只在服务商给过 id 时才把它带回去。
  final bool idFromProvider;

  final String name;

  /// 模型输出的参数原文。
  final String argumentsRaw;

  /// 解析后的参数；原文不是 JSON 对象时为 null，原因见 [argumentsError]。
  final Map<String, Object?>? arguments;

  final String? argumentsError;

  /// 协议附带在调用上、需要原样带回的数据：Gemini 的 `thoughtSignature`、
  /// Responses 的 `fc_` 条目 id 等。
  final Map<String, Object?>? providerData;

  bool get hasValidArguments => arguments != null;
}

/// 助手消息里的一次工具调用。
@immutable
class AiToolCallPart extends AiPart {
  const AiToolCallPart(this.call);

  final AiToolCall call;
}

/// 用户消息里的一个工具结果，按 [callId] 对应到前一条助手消息里的调用。
@immutable
class AiToolResultPart extends AiPart {
  const AiToolResultPart({
    required this.callId,
    required this.name,
    required this.content,
    this.isError = false,
  });

  final String callId;
  final String name;

  /// 给模型看的结果（通常是 JSON 文本）。
  final String content;

  final bool isError;
}

/// 某个协议要求原样带回的数据，只放在助手消息里、只发回产生它的同一个
/// 服务商与模型（一轮之内模型固定，所以不会串）：
/// - Anthropic：整块的 `thinking`（含 `signature`）/ `redacted_thinking`；
/// - OpenAI Responses：本步输出的全部条目（`reasoning` 带
///   `encrypted_content`、`message`、`function_call`）；
/// - OpenAI Chat 兼容：`reasoning_content` / `reasoning` 字段与 OpenRouter
///   的 `reasoning_details`。
@immutable
class AiReplayPart extends AiPart {
  const AiReplayPart(this.protocol, this.data);

  final AiProtocol protocol;
  final Map<String, Object?> data;
}

/// 流中途的提示：第 [index] 个工具调用开始生成。
@immutable
class AiToolCallStart {
  const AiToolCallStart({required this.index, required this.name});

  final int index;
  final String name;
}
