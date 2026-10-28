import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../explore/models/explore_layout.dart';
import '../../../explore/models/explore_presets.dart';
import '../../../explore/models/explore_settings.dart';
import '../../controllers/explore_layout_editor_controller.dart';
import '../../widgets/style_editor/style_library_tab.dart';
import 'explore_layout_labels.dart';

/// “预设”标签页：内置布局、我的布局与布局码（通用实现见 [StyleLibraryTab]）。
/// 套用内置布局只换卡片与范围条、保留外观；我的布局与布局码携带整套布局
/// （含外观），都不改统计范围。
class ExploreLayoutPresetsTab extends StatelessWidget {
  const ExploreLayoutPresetsTab({super.key, required this.controller});

  final ExploreLayoutEditorController controller;

  @override
  Widget build(BuildContext context) {
    return StyleLibraryTab<ExploreLayout, ExploreSettings, ExplorePreset>(
      controller: controller,
      presets: ExploreLayoutLabels.presets(context.l10n),
      matchingPreset: controller.matchingPreset,
      applyPreset: controller.applyPreset,
    );
  }
}
