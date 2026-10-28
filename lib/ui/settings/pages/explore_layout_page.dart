import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../explore/models/explore_module_id.dart';
import '../controllers/explore_layout_editor_controller.dart';
import '../sections/explore_layout/explore_layout_appearance_tab.dart';
import '../sections/explore_layout/explore_layout_cards_tab.dart';
import '../sections/explore_layout/explore_layout_presets_tab.dart';
import '../sections/explore_layout/explore_layout_preview.dart';
import '../sections/explore_layout/explore_layout_range_tab.dart';
import '../widgets/style_editor/style_editor_common.dart';
import '../widgets/style_editor/style_editor_scaffold.dart';

/// 自定义探索页（探索页顶栏“自定义”、长按卡片“卡片设置”，以及设置 → 外观
/// 与语言 → 探索页）。
///
/// 页面壳层：上方是实时预览（真实卡片，[ExploreLayoutPreview]），下方按标签
/// 页分组调整（预设、卡片、外观、范围）；布局与三档面板见
/// [StyleEditorScaffold]。状态与写入由 [ExploreLayoutEditorController] 负责，
/// 改动即时生效；右上角“重置”回到默认布局并提供撤销，统计范围不受影响。
/// [focus] 给出时直接停在“卡片”页并展开这张卡。
class ExploreLayoutPage extends StatefulWidget {
  const ExploreLayoutPage({
    super.key,
    required this.settingsService,
    this.focus,
  });

  final SettingsService settingsService;
  final ExploreModuleId? focus;

  static Route<void> route({
    required SettingsService settingsService,
    ExploreModuleId? focus,
  }) => MaterialPageRoute<void>(
    builder: (_) =>
        ExploreLayoutPage(settingsService: settingsService, focus: focus),
  );

  @override
  State<ExploreLayoutPage> createState() => _ExploreLayoutPageState();
}

class _ExploreLayoutPageState extends State<ExploreLayoutPage> {
  late final ExploreLayoutEditorController _controller =
      ExploreLayoutEditorController(settingsService: widget.settingsService);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final message = context.l10n.exploreLayoutResetDone;
    final previous = await _controller.reset();
    if (!mounted) return;
    unawaited(
      showStyleEditorUndoSnackBar(
        context,
        message: message,
        onUndo: () => _controller.applyStyle(previous),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StyleEditorScaffold(
      title: l10n.exploreCustomize,
      listenable: _controller,
      isDefault: () => _controller.style.isDefault,
      onReset: _reset,
      initialIndex: widget.focus == null ? 0 : 1,
      tabs: <String>[
        l10n.exploreLayoutTabPresets,
        l10n.exploreLayoutTabCards,
        l10n.exploreLayoutTabAppearance,
        l10n.exploreLayoutTabRange,
      ],
      tabViews: () => <Widget>[
        ExploreLayoutPresetsTab(controller: _controller),
        ExploreLayoutCardsTab(controller: _controller, focus: widget.focus),
        ExploreLayoutAppearanceTab(controller: _controller),
        ExploreLayoutRangeTab(controller: _controller),
      ],
      toolbarBuilder: (_) =>
          ExploreLayoutPreviewToolbar(controller: _controller),
      previewArea: AppBackgroundArea.explore,
      previewBuilder:
          ({required bool showToolbar, required double bottomPadding}) =>
              ExploreLayoutPreview(
                controller: _controller,
                showToolbar: showToolbar,
                bottomPadding: bottomPadding,
              ),
    );
  }
}
