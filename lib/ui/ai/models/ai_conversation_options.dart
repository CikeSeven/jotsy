// 一段对话的回答选项：用哪个模型、思考强度（存进 `ai_conversations.options`，
// v21）。
//
// 每段对话各自记住；新对话沿用最近活动的那段对话的选项
// （`latestAiConversationOptions`）。模型引用指向本机的服务商配置（不随
// 备份），恢复到别的设备上解析不到时自动跟随“对话”任务的默认模型；思考
// 强度为 null 时是“自动”（不发强度参数）。
//
// 编解码逐字段容错、稀疏写入：全部跟随默认时为 `{}`。

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';

@immutable
class AiConversationOptions {
  const AiConversationOptions({this.model, this.thinking});

  /// 换用的模型；null 跟随“对话”任务的模型。
  final AiModelRef? model;

  /// 思考强度；null 为自动。
  final AiThinkingLevel? thinking;

  static const AiConversationOptions defaults = AiConversationOptions();

  AiConversationOptions withModel(AiModelRef? value) =>
      AiConversationOptions(model: value, thinking: thinking);

  AiConversationOptions withThinking(AiThinkingLevel? value) =>
      AiConversationOptions(model: model, thinking: value);

  String encode() => jsonEncode(<String, Object?>{
    if (model != null) 'model': model!.toJson(),
    if (thinking != null) 'thinking': thinking!.name,
  });

  static AiConversationOptions decode(String? raw) {
    if (raw == null || raw.isEmpty || raw == '{}') return defaults;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return defaults;
      return AiConversationOptions(
        model: AiModelRef.fromJson(json['model']),
        thinking: AiThinkingLevel.parse(json['thinking']),
      );
    } on FormatException {
      return defaults;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AiConversationOptions &&
      other.model == model &&
      other.thinking == thinking;

  @override
  int get hashCode => Object.hash(model, thinking);
}
