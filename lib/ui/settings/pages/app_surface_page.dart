import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/app_surface_editor_controller.dart';
import '../sections/app_surface/app_surface_background_tab.dart';
import '../sections/app_surface/app_surface_glass_tab.dart';
import '../sections/app_surface/app_surface_preview.dart';
import '../widgets/style_editor/style_editor_common.dart';
import '../widgets/style_editor/style_editor_scaffold.dart';

/// 设置 → 外观与语言 → 背景与材质。
///
/// 页面壳层：上方是实时预览（一块缩小的手机页面，见 [AppSurfacePreview]），
/// 下方两个标签页——背景（全局与各区域的背景）与玻璃（组件材质）；布局与
/// 三档面板见 [StyleEditorScaffold]。状态与写入由
/// [AppSurfaceEditorController] 负责，改动即时生效；右上角“重置”回到默认
/// 并提供撤销。
///
/// 生命周期里的背景图清理：打开时清一次（上次留下的、早已过了撤销窗口的
/// 文件，以及选图途中关掉页面留下的文件），关闭时再清一次；清理一律在写入
/// 完成后、按已保存的引用进行，重置的撤销窗口仍开着时保留快照里的图片
/// （见控制器）。
class AppSurfacePage extends StatefulWidget {
  const AppSurfacePage({
    super.key,
    required this.settingsService,
    this.pickImage,
    this.deleteUnreferenced,
    this.resolveImage,
  });

  final SettingsService settingsService;

  /// 测试注入：选图、清理与解析文件（缺省经 `AppBackgroundStorageService`）。
  final AppBackgroundImagePicker? pickImage;
  final AppBackgroundImageCleaner? deleteUnreferenced;
  final AppBackgroundImageResolver? resolveImage;

  @override
  State<AppSurfacePage> createState() => _AppSurfacePageState();
}

class _AppSurfacePageState extends State<AppSurfacePage> {
  late final AppSurfaceEditorController _controller =
      AppSurfaceEditorController(
        settingsService: widget.settingsService,
        pickImage: widget.pickImage,
        deleteUnreferenced: widget.deleteUnreferenced,
        resolveImage: widget.resolveImage,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.cleanUpImages());
  }

  @override
  void dispose() {
    // 控制器释放后仍能清理：它只读已写入的设置并等待进行中的写入。
    unawaited(_controller.cleanUpImages());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final message = context.l10n.styleEditorResetDone;
    final previous = await _controller.reset();
    if (!mounted) return;
    _controller.holdUndo(previous);
    await showStyleEditorUndoSnackBar(
      context,
      message: message,
      onUndo: () => _controller.applyStyle(previous),
    );
    // 撤销窗口关闭：快照里的图片不再需要保留（页面已关闭时由下次打开清理）。
    _controller.releaseUndo(previous);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StyleEditorScaffold(
      title: l10n.appSurfaceTitle,
      listenable: _controller,
      isDefault: () => _controller.style.isDefault,
      onReset: _reset,
      tabs: <String>[l10n.appSurfaceTabBackground, l10n.appSurfaceTabGlass],
      tabViews: () => <Widget>[
        AppSurfaceBackgroundTab(controller: _controller),
        AppSurfaceGlassTab(controller: _controller),
      ],
      // 预览只有一个明暗按钮，放进标题栏，不单独占一行挤占预览。
      actionsBuilder: (_) => <Widget>[
        StylePreviewBrightnessButton(controller: _controller, inAppBar: true),
      ],
      previewBuilder:
          ({required bool showToolbar, required double bottomPadding}) =>
              AppSurfacePreview(
                controller: _controller,
                bottomPadding: bottomPadding,
              ),
    );
  }
}
