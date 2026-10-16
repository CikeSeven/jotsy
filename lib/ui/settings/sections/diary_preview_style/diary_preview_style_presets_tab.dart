import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_presets.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_settings.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_style.dart';
import '../../controllers/diary_preview_style_editor_controller.dart';
import '../../widgets/style_editor/style_library_tab.dart';
import 'diary_preview_style_labels.dart';

/// 预览页样式的“预设”标签页：内置风格、我的样式与样式码（通用实现见
/// [StyleLibraryTab]）。套用与导入只改外观，阅读行为保持不变。
class DiaryPreviewStylePresetsTab extends StatelessWidget {
  const DiaryPreviewStylePresetsTab({super.key, required this.controller});

  final DiaryPreviewStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    return StyleLibraryTab<
      DiaryPreviewStyle,
      DiaryPreviewSettings,
      DiaryPreviewPresetId
    >(
      controller: controller,
      presets: diaryPreviewPresetOptions(context.l10n),
      matchingPreset: controller.matchingPreset,
      applyPreset: controller.applyPreset,
    );
  }
}
