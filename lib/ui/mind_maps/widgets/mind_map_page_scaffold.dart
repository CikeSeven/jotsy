import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/floating_top_bar/floating_action_island.dart';
import '../../widgets/floating_top_bar/floating_island.dart';
import '../../widgets/floating_top_bar/floating_top_bar.dart';
import '../../widgets/floating_top_bar/floating_top_bar_host.dart';
import '../../widgets/snack_bar_clearance.dart';
import '../controllers/mind_map_editing_controller.dart';
import 'mind_map_view_switch.dart';

/// 导图全屏页（导图日记的编辑页、嵌入导图的编辑页与查看页）共用的外框：
/// 编辑区背景与浮岛顶栏——左返回岛、中间“画布 / 大纲”切换岛
/// （[MindMapViewSwitch]，不显示导图名）、右动作胶囊（撤销 / 重做、宿主的
/// 图标按钮与“更多”，“更多”始终在最右侧）。
///
/// 画布铺满整页，浮岛压在画布上（不画整条栏），[body] 拿到被状态栏与浮岛
/// 盖住的高度作为 `topInset`，据此把适配视图与大纲留在岛的下面。
///
/// 显隐：浮岛随大纲往下滚收起；画布平移缩放时、点空白时由工作区冒泡
/// [FloatingTopBarRevealNotification] 收起或浮出（见 `MindMapWorkspace`）。
///
/// 窄屏：右侧动作多（新建页的“发布”、手动保存的“保存”）时中间放不下
/// 切换岛，切换改为“更多”里的一项（中间留空，不溢出）。
class MindMapPageScaffold extends StatefulWidget {
  const MindMapPageScaffold({
    super.key,
    required this.controller,
    required this.onBack,
    required this.body,
    this.actions = const <Widget>[],
    this.menuItems = const <Widget>[],
    this.menuTooltip,
    this.paintBackground = true,
  });

  /// 编辑会话：视图切换读写它；不是只读时动作胶囊带撤销 / 重做。
  final MindMapEditingController controller;
  final VoidCallback onBack;

  /// 动作胶囊里撤销 / 重做之后、“更多”之前的按钮。
  final List<Widget> actions;

  /// “更多”菜单的项；为空时没有“更多”（视图切换挤进菜单时仍会出现）。
  final List<Widget> menuItems;

  /// “更多”的提示文字，缺省为导图的“更多”。
  final String? menuTooltip;
  final Widget Function(BuildContext context, double topInset) body;

  /// 是否自己画编辑区背景；宿主外面已经画了（日记编辑页）时传 false。
  final bool paintBackground;

  @override
  State<MindMapPageScaffold> createState() => _MindMapPageScaffoldState();
}

class _MindMapPageScaffoldState extends State<MindMapPageScaffold> {
  /// 视图切换此刻是否在顶栏中间（放不下时改进“更多”）。
  final ValueNotifier<bool> _switchInBar = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _switchInBar.dispose();
    super.dispose();
  }

  /// 中间那一格在布局时才知道自己有多宽，结论留到这一帧之后再改，免得
  /// 在布局中途让“更多”重建。
  void _reportSwitchFits(bool fits) {
    if (_switchInBar.value == fits) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _switchInBar.value = fits;
    });
  }

  /// 切换岛与右岛之间的空隙：右岛宽时 [NavigationToolbar] 把中间那一格
  /// 贴着右岛摆（不留间距），左侧的间距由它自己保证。
  static const double _switchGap = 8;

  Widget _buildMiddle() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final fits =
            constraints.maxWidth >= MindMapViewSwitch.width + _switchGap;
        _reportSwitchFits(fits);
        return fits
            ? Padding(
                padding: const EdgeInsetsDirectional.only(end: _switchGap),
                child: MindMapViewSwitch(controller: widget.controller),
              )
            : const SizedBox.shrink();
      },
    );
  }

  /// 挤进“更多”时的那一项：去另一种视图。
  Widget _viewMenuItem(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final outline = controller.outlineView;
    return ExpressiveMenuItem(
      leadingIcon: FaIcon(
        outline ? FontAwesomeIcons.sitemap : FontAwesomeIcons.listUl,
      ),
      onPressed: () {
        controller.stopEditing();
        controller.outlineView = !outline;
      },
      child: Text(outline ? l10n.mindMapCanvasView : l10n.mindMapOutline),
    );
  }

  Widget _buildMore() {
    return ValueListenableBuilder<bool>(
      valueListenable: _switchInBar,
      builder: (BuildContext context, bool inBar, Widget? _) {
        if (inBar && widget.menuItems.isEmpty) return const SizedBox.shrink();
        Widget menu(BuildContext context) => ExpressiveMenuButton(
          tooltip: widget.menuTooltip ?? context.l10n.mindMapMore,
          icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16),
          items: <Widget>[
            if (!inBar) _viewMenuItem(context),
            ...widget.menuItems,
          ],
        );
        return inBar
            ? menu(context)
            : ListenableBuilder(
                listenable: widget.controller,
                builder: (BuildContext context, Widget? _) => menu(context),
              );
      },
    );
  }

  Widget _buildUndoRedo(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: l10n.mindMapUndo,
            onPressed: controller.canUndo ? controller.undo : null,
            icon: const FaIcon(FontAwesomeIcons.arrowRotateLeft, size: 16),
          ),
          IconButton(
            tooltip: l10n.mindMapRedo,
            onPressed: controller.canRedo ? controller.redo : null,
            icon: const FaIcon(FontAwesomeIcons.arrowRotateRight, size: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = Builder(
      builder: (BuildContext context) {
        final topInset =
            MediaQuery.viewPaddingOf(context).top + FloatingTopBar.extent;
        return SnackBarClearanceHost(
          resizeToAvoidBottomInset: false,
          child: Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            resizeToAvoidBottomInset: false,
            body: FloatingTopBarHost(
              statusBarColor: AppPageBackdrop.solidBarColorOf(context),
              hideOnScroll: true,
              leading: FloatingBackIsland(onPressed: widget.onBack),
              middle: _buildMiddle(),
              trailing: FloatingActionIsland(
                children: <Widget>[
                  if (!widget.controller.readOnly) _buildUndoRedo(context),
                  ...widget.actions,
                  _buildMore(),
                ],
              ),
              child: SizedBox.expand(child: widget.body(context, topInset)),
            ),
          ),
        );
      },
    );
    return widget.paintBackground
        ? AppPageBackground(area: AppBackgroundArea.editor, child: page)
        : page;
  }
}
