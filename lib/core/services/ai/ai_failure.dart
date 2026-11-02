import 'dart:convert';

/// AI 请求失败的类别，界面按它给出说明与下一步（如“去设置检查密钥”）。
enum AiFailureKind {
  /// 没有可用的服务商或模型。
  notConfigured,

  /// 连不上（断网、DNS、TLS、连接被重置）。
  network,

  /// 连接、首个字节或两块之间等待超时。
  timeout,

  /// 密钥无效或缺失（401）。
  unauthorized,

  /// 没有权限、地区不可用（403）。
  forbidden,

  /// 模型不存在或地址写错（404）。
  modelNotFound,

  /// 请求太频繁（429）。
  rateLimited,

  /// 余额或额度不足（402，或错误信息里写明）。
  quota,

  /// 内容超过模型的上下文长度。
  contextTooLong,

  /// 被服务端的安全策略拦下。
  contentFiltered,

  /// 请求格式不被接受（其余 4xx）。
  badRequest,

  /// 服务端出错（5xx、过载）。
  server,

  /// 响应无法解析（地址填成了网页、代理改写了响应等）。
  badResponse,

  /// 用户停止。
  cancelled;

  /// 值得自动重试的失败：只在首个字节之前重试，见 `AiService`。
  bool get retryable =>
      this == network ||
      this == timeout ||
      this == rateLimited ||
      this == server;
}

class AiException implements Exception {
  const AiException(
    this.kind, {
    this.statusCode,
    this.providerMessage,
    this.detail,
  });

  final AiFailureKind kind;
  final int? statusCode;

  /// 服务端返回的错误原文（给用户“查看详情”）。
  final String? providerMessage;

  /// 本地补充的诊断信息（异常类型等）。
  final String? detail;

  /// 按 HTTP 状态码与错误体归类。错误体先按三种协议的常见形状取出说明：
  /// - OpenAI 兼容：`{"error": {"message", "type", "code"}}`；
  /// - Anthropic：`{"type": "error", "error": {"type", "message"}}`；
  /// - Gemini：`{"error": {"code", "message", "status"}}`；
  /// 有的服务商直接返回 `{"message": ...}` 或纯文本，也照样保留原文。
  factory AiException.fromResponse(int statusCode, String body) {
    final message = aiErrorMessageOf(body);
    final lower = '${message ?? ''} $body'.toLowerCase();
    final kind = _classify(statusCode, lower);
    return AiException(
      kind,
      statusCode: statusCode,
      providerMessage: message ?? _clip(body),
    );
  }

  static AiFailureKind _classify(int statusCode, String lower) {
    if (_mentionsContextLength(lower)) return AiFailureKind.contextTooLong;
    if (_mentionsQuota(lower)) return AiFailureKind.quota;
    if (lower.contains('overloaded')) return AiFailureKind.server;
    switch (statusCode) {
      case 401:
        return AiFailureKind.unauthorized;
      case 402:
        return AiFailureKind.quota;
      case 403:
        return AiFailureKind.forbidden;
      case 404:
        return AiFailureKind.modelNotFound;
      case 408:
        return AiFailureKind.timeout;
      case 413:
        return AiFailureKind.contextTooLong;
      case 429:
        return AiFailureKind.rateLimited;
    }
    if (statusCode >= 500) return AiFailureKind.server;
    if (lower.contains('safety') ||
        lower.contains('content_filter') ||
        lower.contains('content filter')) {
      return AiFailureKind.contentFiltered;
    }
    // 有的服务商把无效密钥报成 400。
    if (lower.contains('api key') || lower.contains('api_key')) {
      return AiFailureKind.unauthorized;
    }
    return AiFailureKind.badRequest;
  }

  static bool _mentionsContextLength(String lower) =>
      lower.contains('context_length') ||
      lower.contains('context length') ||
      lower.contains('maximum context') ||
      lower.contains('too many tokens') ||
      lower.contains('prompt is too long') ||
      lower.contains('input is too long') ||
      lower.contains('exceeds the maximum');

  static bool _mentionsQuota(String lower) =>
      lower.contains('insufficient_quota') ||
      lower.contains('insufficient balance') ||
      lower.contains('insufficient_balance') ||
      lower.contains('credit balance') ||
      lower.contains('quota exceeded') ||
      lower.contains('余额不足') ||
      lower.contains('欠费');

  @override
  String toString() {
    final parts = <String>[
      kind.name,
      if (statusCode != null) 'HTTP $statusCode',
      if (providerMessage != null) providerMessage!,
      if (detail != null) detail!,
    ];
    return 'AiException(${parts.join(', ')})';
  }
}

/// 从错误响应体里取出给人看的说明；取不到时返回 null。
String? aiErrorMessageOf(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    return null;
  }
  // Gemini 的流式错误可能包在数组里。
  if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
  if (decoded is! Map) return null;
  final error = decoded['error'];
  if (error is Map) {
    final message = error['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
    final code = error['code'] ?? error['type'] ?? error['status'];
    if (code != null) return '$code';
  }
  if (error is String && error.trim().isNotEmpty) return error.trim();
  final message = decoded['message'] ?? decoded['msg'] ?? decoded['detail'];
  if (message is String && message.trim().isNotEmpty) return message.trim();
  return null;
}

String _clip(String body) {
  final trimmed = body.trim();
  if (trimmed.length <= 400) return trimmed;
  return '${trimmed.substring(0, 400)}…';
}
