import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/diary_code_block_style_editor_controller.dart';
import '../sections/diary_code_block_style/diary_code_block_style_display_tab.dart';
import '../sections/diary_code_block_style/diary_code_block_style_font_tab.dart';
import '../sections/diary_code_block_style/diary_code_block_style_preview.dart';
import '../sections/diary_code_block_style/diary_code_block_style_theme_tab.dart';
import '../widgets/style_editor/style_editor_common.dart';
import '../widgets/style_editor/style_editor_scaffold.dart';

/// 设置 → 编辑器设置 → 代码块样式（也可从工具栏排序页代码块工具的齿轮
/// 进入）。
///
/// 页面壳层：上方是实时预览（一段行内代码与两个示例代码块），下方按标签页
/// 分组调整（配色、显示、字体）；布局与三档面板见 [StyleEditorScaffold]。
/// 状态与写入由 [DiaryCodeBlockStyleEditorController] 负责，改动即时生效；
/// 右上角“重置”回到默认样式并提供撤销。
class DiaryCodeBlockStylePage extends StatefulWidget {
  const DiaryCodeBlockStylePage({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  State<DiaryCodeBlockStylePage> createState() =>
      _DiaryCodeBlockStylePageState();
}

class _DiaryCodeBlockStylePageState extends State<DiaryCodeBlockStylePage> {
  late final DiaryCodeBlockStyleEditorController _controller =
      DiaryCodeBlockStyleEditorController(
        settingsService: widget.settingsService,
      );

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
      title: l10n.codeBlockStyleTitle,
      listenable: _controller,
      isDefault: () => _controller.style.isDefault,
      onReset: _reset,
      tabs: <String>[
        l10n.codeBlockStyleTabTheme,
        l10n.codeBlockStyleTabDisplay,
        l10n.codeBlockStyleTabFont,
      ],
      tabViews: () => <Widget>[
        DiaryCodeBlockStyleThemeTab(controller: _controller),
        DiaryCodeBlockStyleDisplayTab(controller: _controller),
        DiaryCodeBlockStyleFontTab(controller: _controller),
      ],
      // 预览只有一个明暗按钮，放进标题栏，不单独占一行挤占预览。
      actionsBuilder: (_) => <Widget>[
        StylePreviewBrightnessButton(controller: _controller, inAppBar: true),
      ],
      previewBuilder:
          ({required bool showToolbar, required double bottomPadding}) =>
              DiaryCodeBlockStylePreview(
                controller: _controller,
                bottomPadding: bottomPadding,
              ),
    );
  }
}
