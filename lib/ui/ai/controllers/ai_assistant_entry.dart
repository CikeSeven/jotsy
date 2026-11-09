// AI 助手的统一入口（日记页顶栏 ✨、探索卡片“问问我的日记”、AI 设置的
// “打开 AI 助手”）：对话模块可用时直接进新对话（欢迎页里有快捷问题、回顾
// 与最近的对话，历史在左侧抽屉）；只开着回顾时进回顾页。两个都不可用时
// 入口本身就不出现（`aiHubAvailableProvider`）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_preference_parts.dart';
import '../pages/ai_chat_page.dart';
import '../pages/ai_recap_page.dart';
import '../providers/ai_providers.dart';

Future<void> openAiAssistant(BuildContext context, WidgetRef ref) {
  final chat = ref.read(aiModuleAvailableProvider(AiModule.chat));
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => chat ? const AiChatPage() : const AiRecapPage(),
    ),
  );
}

/// 打开一段已有的对话（存储管理里“用在”某段 AI 对话的图片）。调用方负责
/// 只在 AI 助手开着时提供这个入口。
Future<void> openAiConversation(BuildContext context, String conversationId) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AiChatPage(conversationId: conversationId),
    ),
  );
}
