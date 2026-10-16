import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../diaries/models/diary_card_style/diary_card_style_presets.dart';
import '../../../diaries/models/diary_card_style/diary_card_style_settings.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import '../../widgets/style_editor/style_library_tab.dart';
import '../../widgets/style_editor/style_preset_grid.dart';
import 'diary_card_style_labels.dart';

/// 卡片样式的“预设”标签页：内置风格、我的样式与样式码（通用实现见
/// [StyleLibraryTab]）。
class DiaryCardStylePresetsTab extends StatelessWidget {
  const DiaryCardStylePresetsTab({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StyleLibraryTab<
      DiaryCardStyle,
      DiaryCardStyleSettings,
      DiaryCardPresetId
    >(
      controller: controller,
      presets: <StylePresetOption<DiaryCardPresetId>>[
        for (final id in DiaryCardPresetId.values)
          StylePresetOption<DiaryCardPresetId>(
            id: id,
            icon: diaryCardPresetIcon(id),
            name: diaryCardPresetName(l10n, id),
            description: diaryCardPresetDescription(l10n, id),
          ),
      ],
      matchingPreset: controller.matchingPreset,
      applyPreset: controller.applyPreset,
    );
  }
}
