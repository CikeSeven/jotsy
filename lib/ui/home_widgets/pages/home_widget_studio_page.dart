import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../core/services/home_widgets/home_widget_kind.dart';
import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../settings/widgets/style_editor/style_editor_scaffold.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../controllers/home_widget_studio_controller.dart';
import '../controllers/home_widget_style_library_controller.dart';
import '../providers/home_widget_providers.dart';
import '../sections/home_widget_content_tab.dart';
import '../sections/home_widget_library_tab.dart';
import '../sections/home_widget_studio_preview.dart';
import '../sections/home_widget_style_tab.dart';
import '../widgets/home_widget_kind_labels.dart';
import '../widgets/home_widget_preview_demand.dart';

/// 小组件工作室：一个小组件的内容与外观。
///
/// 页面壳层沿用样式编辑页（[StyleEditorScaffold]）：上方是原生画出来的真实
/// 预览（可切尺寸与明暗），下方两个标签页（内容、样式）。状态与写入由
/// [HomeWidgetStudioController] 负责：编辑桌面上已有的小组件时改动即时同步
/// 到桌面；设计新的小组件时预览下方是“添加到桌面”。右上角“重置”回到该
/// 种类的默认配置并提供撤销。
class HomeWidgetStudioPage extends ConsumerStatefulWidget {
  const HomeWidgetStudioPage({
    super.key,
    required this.settingsService,
    required this.kind,
    this.widgetId,
  });

  final SettingsService settingsService;
  final HomeWidgetKind kind;

  /// 桌面上的实例；为 null 时是在组件库里设计一个新的。
  final int? widgetId;

  @override
  ConsumerState<HomeWidgetStudioPage> createState() =>
      _HomeWidgetStudioPageState();
}

class _HomeWidgetStudioPageState extends ConsumerState<HomeWidgetStudioPage>
    with HomeWidgetPreviewDemandMixin {
  late final HomeWidgetStudioController _controller;

  @override
  void initState() {
    super.initState();
    final widgetId = widget.widgetId;
    final settings = ref.read(homeWidgetSettingsProvider);
    _controller = HomeWidgetStudioController(
      settingsService: widget.settingsService,
      readSettings: () => ref.read(homeWidgetSettingsProvider),
      widgetId: widgetId,
      initial: widgetId == null
          ? HomeWidgetInstance.defaultsFor(widget.kind)
          : settings.instanceFor(widgetId, widget.kind),
    );
    _library = HomeWidgetStyleLibraryController(
      settingsService: widget.settingsService,
      readSettings: () => ref.read(homeWidgetSettingsProvider),
    );
    // 草稿的内容交给快照（预览要画出它选的来源）；进出页面在帧回调里改 provider，
    // 理由同 HomeWidgetPreviewDemandMixin。
    _previewContent = ref.read(homeWidgetPreviewContentProvider.notifier);
    _controller.addListener(_showPreviewContent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPreviewContent());
  }

  late final HomeWidgetStyleLibraryController _library;
  late final HomeWidgetPreviewContent _previewContent;
  HomeWidgetContent? _shownContent;

  void _showPreviewContent() {
    if (!mounted || identical(_shownContent, _controller.content)) return;
    _shownContent = _controller.content;
    _previewContent.show(_shownContent);
  }

  @override
  void dispose() {
    _controller.removeListener(_showPreviewContent);
    final previewContent = _previewContent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previewContent.show(null);
    });
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final message = context.l10n.styleEditorResetDone;
    final previous = _controller.reset();
    unawaited(
      showStyleEditorUndoSnackBar(
        context,
        message: message,
        onUndo: () => _controller.restore(previous),
      ),
    );
  }

  Future<void> _addToHome() async {
    final gateway = ref.read(homeWidgetGatewayProvider);
    if (gateway == null) return;
    final l10n = context.l10n;
    final result = await _controller.requestPin(gateway);
    if (!mounted) return;
    switch (result) {
      case HomeWidgetPinResult.requested:
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(content: Text(l10n.homeWidgetPinRequested)),
        );
      case HomeWidgetPinResult.unsupported || HomeWidgetPinResult.failed:
        await showAppDialog<void>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.homeWidgetPinUnsupportedTitle),
            content: Text(
              l10n.homeWidgetPinUnsupportedBody(
                homeWidgetKindName(l10n, widget.kind),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonConfirm),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StyleEditorScaffold(
      title: homeWidgetKindName(l10n, widget.kind),
      listenable: _controller,
      isDefault: () => _controller.isDefault,
      onReset: _reset,
      tabs: <String>[
        l10n.homeWidgetTabPresets,
        l10n.homeWidgetTabContent,
        l10n.homeWidgetTabStyle,
      ],
      tabViews: () => <Widget>[
        HomeWidgetLibraryTab(controller: _controller, library: _library),
        HomeWidgetContentTab(controller: _controller),
        HomeWidgetStyleTab(controller: _controller),
      ],
      actionsBuilder: (BuildContext context) => <Widget>[
        _PreviewBrightnessButton(controller: _controller),
      ],
      previewBuilder:
          ({required bool showToolbar, required double bottomPadding}) =>
              HomeWidgetStudioPreview(
                controller: _controller,
                bottomPadding: bottomPadding,
                onAddToHome: _controller.isNew ? _addToHome : null,
              ),
    );
  }
}

/// 标题栏里的预览明暗切换：只换预览，不改应用主题；图标显示点按后会切到的
/// 那一种（与样式编辑页的同名按钮一致）。
class _PreviewBrightnessButton extends StatelessWidget {
  const _PreviewBrightnessButton({required this.controller});

  final HomeWidgetStudioController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dark =
        controller.previewDark ??
        Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark
          ? l10n.styleEditorPreviewLight
          : l10n.styleEditorPreviewDark,
      onPressed: () => controller.previewDark = !dark,
      icon: FaIcon(
        dark ? FontAwesomeIcons.sun : FontAwesomeIcons.moon,
        size: 18,
      ),
    );
  }
}
