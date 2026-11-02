import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/ai/ai_provider_config.dart';
import '../pages/settings/ai_provider_edit_page.dart';
import '../sections/settings/ai_preset_sheet.dart';

/// 添加服务商：先在预设面板里挑一个，再进入编辑页（以预设预填）。面板
/// 关掉时什么都不做。
Future<void> addAiProviderFlow(BuildContext context, WidgetRef ref) async {
  final preset = await showAiPresetSheet(context);
  if (preset == null || !context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => AiProviderEditPage.create(preset),
    ),
  );
}

/// 编辑已有的服务商。
Future<void> editAiProviderFlow(
  BuildContext context,
  AiProviderConfig provider,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => AiProviderEditPage.edit(provider),
    ),
  );
}
