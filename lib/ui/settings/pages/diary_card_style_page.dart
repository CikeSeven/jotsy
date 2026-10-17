import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_card_style/diary_card_style.dart';
import '../controllers/diary_card_style_editor_controller.dart';
import '../sections/diary_card_style/diary_card_style_color_tab.dart';
import '../sections/diary_card_style/diary_card_style_content_tab.dart';
import '../sections/diary_card_style/diary_card_style_cover_tab.dart';
import '../sections/diary_card_style/diary_card_style_date_tab.dart';
import '../sections/diary_card_style/diary_card_style_layout_tab.dart';
import '../sections/diary_card_style/diary_card_style_order_tab.dart';
import '../sections/diary_card_style/diary_card_style_presets_tab.dart';
import '../sections/diary_card_style/diary_card_style_preview.dart';
import '../sections/diary_card_style/diary_card_style_samples.dart';
import '../sections/diary_card_style/diary_card_style_text_tab.dart';
import '../sections/diary_card_style/diary_card_style_texture_tab.dart';
import '../widgets/style_editor/style_editor_common.dart';
import '../widgets/style_editor/style_editor_scaffold.dart';

/// 设置 → 外观与语言 → 日记卡片样式。
///
/// 页面壳层：上方实时预览，下方按标签页分组调整（预设、布局、封面、内容、
/// 日期、排序、字体、色彩、质感）；布局与三档面板见 [StyleEditorScaffold]。
/// 预览顶部的工具条切换列表 / 瀑布流与明暗。状态与写入由
/// [DiaryCardStyleEditorController] 负责，改动即时生效、无需保存；右上角
/// “重置”回到默认样式并提供撤销。
class DiaryCardStylePage extends StatefulWidget {
  const DiaryCardStylePage({
    super.key,
    required this.settingsService,
    this.initialMode = DiaryCardMode.list,
  });

  final SettingsService settingsService;

  /// 打开时预览与编辑的布局（从日记页进入时取当前布局）。
  final DiaryCardMode initialMode;

  @override
  State<DiaryCardStylePage> createState() => _DiaryCardStylePageState();
}

class _DiaryCardStylePageState extends State<DiaryCardStylePage> {
  late final DiaryCardStyleEditorController _controller =
      DiaryCardStyleEditorController(
        settingsService: widget.settingsService,
        initialMode: widget.initialMode,
      );
  List<DiaryWithTags>? _samples;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    return StyleEditorScaffold(
      title: l10n.diaryCardStyleTitle,
      listenable: _controller,
      isDefault: () => _controller.style.isDefault,
      onReset: _reset,
      tabs: <String>[
        l10n.diaryCardStyleTabPresets,
        l10n.diaryCardStyleTabLayout,
        l10n.diaryCardStyleTabCover,
        l10n.diaryCardStyleTabContent,
        l10n.diaryCardStyleTabDate,
        l10n.diaryCardStyleTabOrder,
        l10n.diaryCardStyleTabText,
        l10n.diaryCardStyleTabColor,
        l10n.diaryCardStyleTabTexture,
      ],
      tabViews: () => <Widget>[
        DiaryCardStylePresetsTab(controller: _controller),
        DiaryCardStyleLayoutTab(controller: _controller),
        DiaryCardStyleCoverTab(controller: _controller),
        DiaryCardStyleContentTab(controller: _controller),
        DiaryCardStyleDateTab(controller: _controller),
        DiaryCardStyleOrderTab(controller: _controller),
        DiaryCardStyleTextTab(controller: _controller),
        DiaryCardStyleColorTab(controller: _controller),
        DiaryCardStyleTextureTab(controller: _controller),
      ],
      toolbarBuilder: (_) =>
          DiaryCardStylePreviewToolbar(controller: _controller),
      previewBuilder:
          ({required bool showToolbar, required double bottomPadding}) =>
              DiaryCardStylePreview(
                controller: _controller,
                samples: _samples!,
                moodOptions: widget.settingsService.moodOptions,
                showToolbar: showToolbar,
                bottomPadding: bottomPadding,
              ),
    );
  }
}
