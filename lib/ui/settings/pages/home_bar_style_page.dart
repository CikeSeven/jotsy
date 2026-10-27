import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../controllers/home_bar_style_editor_controller.dart';
import '../sections/diary_card_style/diary_card_style_samples.dart';
import '../sections/home_bar_style/home_bar_style_behavior_tab.dart';
import '../sections/home_bar_style/home_bar_style_floating_tab.dart';
import '../sections/home_bar_style/home_bar_style_items_tab.dart';
import '../sections/home_bar_style/home_bar_style_material_tab.dart';
import '../sections/home_bar_style/home_bar_style_presets_tab.dart';
import '../sections/home_bar_style/home_bar_style_preview.dart';
import '../sections/home_bar_style/home_bar_style_preview_toolbar.dart';
import '../widgets/style_editor/style_editor_common.dart';
import '../widgets/style_editor/style_editor_scaffold.dart';

/// 设置 → 外观与语言 → 导航栏样式。
///
/// 页面壳层：上方是实时预览（一个缩小的首页：顶栏、示例日记列表与底栏），
/// 下方按标签页分组调整（预设、材质、悬浮栏、导航项、行为）；布局与三档
/// 面板见 [StyleEditorScaffold]。状态与写入由 [HomeBarStyleEditorController]
/// 负责，改动即时生效；右上角“重置”回到默认外观（实色）并提供撤销，栏的
/// 行为不受重置影响。
class HomeBarStylePage extends StatefulWidget {
  const HomeBarStylePage({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  State<HomeBarStylePage> createState() => _HomeBarStylePageState();
}

class _HomeBarStylePageState extends State<HomeBarStylePage> {
  late final HomeBarStyleEditorController _controller =
      HomeBarStyleEditorController(settingsService: widget.settingsService);
  List<DiaryWithTags>? _samples;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 示例文案来自 ARB，需要 context；只生成一次，预览重建时卡片不重新解析。
    _samples ??= buildDiaryCardStyleSamples(context.l10n, now: DateTime.now());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final message = context.l10n.styleEditorResetDone;
    final previous = await _controller.reset();
    if (!mounted) {
      return;
    }
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
    final samples = _samples!;
    return StyleEditorScaffold(
      title: l10n.homeBarStyleTitle,
      listenable: _controller,
      isDefault: () => _controller.style.isDefault,
      onReset: _reset,
      tabs: <String>[
        l10n.homeBarStyleTabPresets,
        l10n.homeBarStyleTabMaterial,
        l10n.homeBarStyleTabFloating,
        l10n.homeBarStyleTabItems,
        l10n.homeBarStyleTabBehavior,
      ],
      tabViews: () => <Widget>[
        HomeBarStylePresetsTab(controller: _controller),
        HomeBarStyleMaterialTab(controller: _controller),
        HomeBarStyleFloatingTab(controller: _controller),
        HomeBarStyleItemsTab(controller: _controller),
        HomeBarStyleBehaviorTab(controller: _controller),
      ],
      toolbarBuilder: (_) =>
          HomeBarStylePreviewToolbar(controller: _controller),
      previewArea: AppBackgroundArea.diaries,
      previewBuilder:
          ({required bool showToolbar, required double bottomPadding}) =>
              HomeBarStylePreview(
                controller: _controller,
                samples: samples,
                showToolbar: showToolbar,
                bottomPadding: bottomPadding,
              ),
    );
  }
}
