import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../controllers/diary_preview_style_editor_controller.dart';
import '../sections/diary_preview_style/diary_preview_style_body_tab.dart';
import '../sections/diary_preview_style/diary_preview_style_cover_tab.dart';
import '../sections/diary_preview_style/diary_preview_style_meta_tab.dart';
import '../sections/diary_preview_style/diary_preview_style_page_tab.dart';
import '../sections/diary_preview_style/diary_preview_style_paging_tab.dart';
import '../sections/diary_preview_style/diary_preview_style_presets_tab.dart';
import '../sections/diary_preview_style/diary_preview_style_preview.dart';
import '../sections/diary_preview_style/diary_preview_style_samples.dart';
import '../sections/diary_preview_style/diary_preview_style_title_tab.dart';
import '../widgets/style_editor/style_editor_common.dart';
import '../widgets/style_editor/style_editor_scaffold.dart';

/// 设置 → 外观与语言 → 日记预览页（也可从预览页“更多 → 页面样式”进入）。
///
/// 页面壳层：上方是实时预览（几篇示例，可左右切换；从某篇日记进入时第一页
/// 就是它），下方按标签页分组调整（预设、页面、头图、标题、信息、正文、
/// 翻页）；
/// 布局与三档面板见 [StyleEditorScaffold]。状态与写入由
/// [DiaryPreviewStyleEditorController] 负责，改动即时生效；右上角“重置”回到
/// 默认外观并提供撤销（阅读行为不受重置影响）。
class DiaryPreviewStylePage extends StatefulWidget {
  const DiaryPreviewStylePage({
    super.key,
    required this.settingsService,
    this.previewDiary,
  });

  final SettingsService settingsService;

  /// 从预览页进入时的那篇日记，作为第一篇示例。
  final DiaryWithTags? previewDiary;

  @override
  State<DiaryPreviewStylePage> createState() => _DiaryPreviewStylePageState();
}

class _DiaryPreviewStylePageState extends State<DiaryPreviewStylePage> {
  late final DiaryPreviewStyleEditorController _controller =
      DiaryPreviewStyleEditorController(
        settingsService: widget.settingsService,
      );
  final ValueNotifier<int> _samplePage = ValueNotifier<int>(0);
  List<DiaryWithTags>? _samples;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _samples ??= <DiaryWithTags>[
      ?widget.previewDiary,
      ...buildDiaryPreviewStyleSamples(context.l10n, now: DateTime.now()),
    ];
  }

  @override
  void dispose() {
    _samplePage.dispose();
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
      title: l10n.diaryPreviewStyleTitle,
      listenable: _controller,
      isDefault: () => _controller.style.isDefault,
      onReset: _reset,
      tabs: <String>[
        l10n.diaryPreviewStyleTabPresets,
        l10n.diaryPreviewStyleTabPage,
        l10n.diaryPreviewStyleTabCover,
        l10n.diaryPreviewStyleTabTitle,
        l10n.diaryPreviewStyleTabMeta,
        l10n.diaryPreviewStyleTabBody,
        l10n.diaryPreviewStyleTabPaging,
      ],
      tabViews: () => <Widget>[
        DiaryPreviewStylePresetsTab(controller: _controller),
        DiaryPreviewStylePageTab(controller: _controller),
        DiaryPreviewStyleCoverTab(controller: _controller),
        DiaryPreviewStyleTitleTab(controller: _controller),
        DiaryPreviewStyleMetaTab(controller: _controller),
        DiaryPreviewStyleBodyTab(controller: _controller),
        DiaryPreviewStylePagingTab(controller: _controller),
      ],
      toolbarBuilder: (_) => DiaryPreviewStylePreviewToolbar(
        controller: _controller,
        page: _samplePage,
        count: samples.length,
      ),
      previewArea: AppBackgroundArea.preview,
      previewBuilder:
          ({required bool showToolbar, required double bottomPadding}) =>
              DiaryPreviewStylePreview(
                controller: _controller,
                samples: samples,
                page: _samplePage,
                showToolbar: showToolbar,
                bottomPadding: bottomPadding,
              ),
    );
  }
}
