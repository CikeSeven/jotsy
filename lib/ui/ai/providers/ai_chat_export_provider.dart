import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/ai_chat_export.dart';

/// 导出对话的选项（格式、是否带思考与操作）：本次运行内记住上次的选择，
/// 不落设置（导出是一次性的动作，没有必要随备份带走）。
final aiChatExportOptionsProvider =
    NotifierProvider<AiChatExportOptionsNotifier, AiChatExportOptions>(
      AiChatExportOptionsNotifier.new,
    );

class AiChatExportOptionsNotifier extends Notifier<AiChatExportOptions> {
  @override
  AiChatExportOptions build() => const AiChatExportOptions();

  void update(AiChatExportOptions value) => state = value;
}
