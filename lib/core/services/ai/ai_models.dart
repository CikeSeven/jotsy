import 'dart:typed_data';

import 'package:meta/meta.dart';

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

  AiRequest copyWith({
    String? model,
    String? system,
    List<AiMessage>? messages,
    double? temperature,
    int? maxOutputTokens,
    bool? reasoning,
  }) {
    return AiRequest(
      model: model ?? this.model,
      system: system ?? this.system,
      messages: messages ?? this.messages,
      temperature: temperature ?? this.temperature,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      reasoning: reasoning ?? this.reasoning,
    );
  }

  bool get hasImages => messages.any((message) => message.hasImages);
}

/// 一次请求消耗的 token。部分服务商不返回用量。
@immutable
class AiUsage {
  const AiUsage({this.inputTokens = 0, this.outputTokens = 0});

  final int inputTokens;
  final int outputTokens;

  int get totalTokens => inputTokens + outputTokens;

  AiUsage operator +(AiUsage other) => AiUsage(
    inputTokens: inputTokens + other.inputTokens,
    outputTokens: outputTokens + other.outputTokens,
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
  );

  @override
  bool operator ==(Object other) =>
      other is AiUsage &&
      other.inputTokens == inputTokens &&
      other.outputTokens == outputTokens;

  @override
  int get hashCode => Object.hash(inputTokens, outputTokens);

  @override
  String toString() => 'AiUsage($inputTokens in, $outputTokens out)';
}

/// 结束原因，统一三种协议的写法。
enum AiFinishReason {
  /// 正常结束。
  stop,

  /// 达到最大输出长度被截断。
  length,

  /// 被服务端的安全策略拦下。
  filtered,

  /// 其他或未知。
  other,
}

/// 流式响应的一块。一块里可以同时带正文增量、思考增量与用量。
@immutable
class AiChunk {
  const AiChunk({
    this.text = '',
    this.reasoning = '',
    this.usage,
    this.finishReason,
  });

  final String text;
  final String reasoning;
  final AiUsage? usage;
  final AiFinishReason? finishReason;

  bool get isEmpty =>
      text.isEmpty &&
      reasoning.isEmpty &&
      usage == null &&
      finishReason == null;
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
  });

  final String text;
  final String reasoning;
  final AiUsage? usage;
  final AiFinishReason? finishReason;
}
