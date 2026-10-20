import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/models/home_bar_style/home_bar_presets.dart';
import '../../../home/models/home_bar_style/home_bar_settings.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/style_editor/style_library_tab.dart';
import 'home_bar_style_labels.dart';

/// 导航栏样式的“预设”标签页：内置风格、我的样式与样式码（通用实现见
/// [StyleLibraryTab]）。套用与导入只改外观，栏的行为保持不变。
class HomeBarStylePresetsTab extends StatelessWidget {
  const HomeBarStylePresetsTab({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    return StyleLibraryTab<HomeBarStyle, HomeBarSettings, HomeBarPreset>(
      controller: controller,
      presets: homeBarPresetOptions(context.l10n),
      matchingPreset: controller.matchingPreset,
      applyPreset: controller.applyPreset,
    );
  }
}
