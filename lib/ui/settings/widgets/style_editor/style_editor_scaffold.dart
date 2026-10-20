import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/app_top_bar.dart';
import '../../../widgets/snap_panel.dart';

/// 样式编辑页（卡片样式、预览页样式、代码块样式）共用的页面外壳。
///
/// 上方实时预览，下方按标签页分组调整。窄屏时选项是一块可拖动的面板
/// （[SnapPanel]），停在三档：上档盖住预览、只留顶部工具条（没有工具条的
/// 页面只留标题栏）；中档为默认，预览
/// 约占四成高度；下档只露出标签栏，预览占满其余空间。宽屏（≥720dp）时预览与
/// 选项左右并排。右上角“重置”在已是默认样式时禁用。
///
/// 标签页之间禁用横滑：选项里有大量滑块与拖拽排序，横滑切页会与它们抢
/// 手势。状态与写入由各页的编辑控制器负责（[listenable]），外壳只管布局。
class StyleEditorScaffold extends StatefulWidget {
  const StyleEditorScaffold({
    super.key,
    required this.title,
    required this.listenable,
    required this.isDefault,
    required this.onReset,
    required this.tabs,
    required this.tabViews,
    this.toolbarBuilder,
    this.actionsBuilder,
    required this.previewBuilder,
  });

  final String title;

  /// 编辑控制器：变化时重建工具条、预览、选项与“重置”按钮。
  final Listenable listenable;
  final bool Function() isDefault;
  final VoidCallback onReset;
  final List<String> tabs;
  final List<Widget> Function() tabViews;

  /// 窄屏时固定在预览上方的工具条（宽屏时由预览自己显示）；为 null 时
  /// 不占这一行。必须在监听回调内重新创建；复用同一个 Widget 会跳过重建，
  /// 让选中态与捕获旧明暗值的按钮回调滞留到页面因其他交互重建时才刷新。
  final WidgetBuilder? toolbarBuilder;

  /// 标题栏里排在“重置”之前的操作按钮（如预览明暗）。工具条只有一两个
  /// 按钮时放这里，不为它单独占一行、挤占预览。随 [listenable] 重建，理由
  /// 同 [toolbarBuilder]。
  final List<Widget> Function(BuildContext context)? actionsBuilder;

  /// 实时预览：[showToolbar] 为宽屏时自带工具条；[bottomPadding] 为窄屏时
  /// 被面板圆角压住的高度，预览末尾多留这段空白。
  final Widget Function({
    required bool showToolbar,
    required double bottomPadding,
  })
  previewBuilder;

  @override
  State<StyleEditorScaffold> createState() => _StyleEditorScaffoldState();
}

class _StyleEditorScaffoldState extends State<StyleEditorScaffold>
    with TickerProviderStateMixin {
  late final SnapPanelController _panel;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _panel = SnapPanelController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 切页动画时长取 ExpressiveMotion token（减少动画时为 0），需要读取
    // MediaQuery，因此在首次 didChangeDependencies 而不是 initState 里创建。
    _tabController ??= TabController(
      length: widget.tabs.length,
      vsync: this,
      animationDuration: ExpressiveMotion.duration(
        context,
        ExpressiveMotion.medium,
      ),
    );
  }

  @override
  void dispose() {
    _panel.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  TabBar _tabBar(TabController controller, {ValueChanged<int>? onTap}) {
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onTap,
      tabs: <Tab>[for (final tab in widget.tabs) Tab(text: tab)],
    );
  }

  String _panelStopLabel(AppLocalizations l10n, SnapPanelStop stop) {
    return switch (stop) {
      SnapPanelStop.collapsed => l10n.styleEditorPanelCollapsed,
      SnapPanelStop.half => l10n.styleEditorPanelHalf,
      SnapPanelStop.expanded => l10n.styleEditorPanelExpanded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabController = _tabController!;
    return Scaffold(
      appBar: AppTopBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        actions: <Widget>[
          ListenableBuilder(
            listenable: widget.listenable,
            builder: (BuildContext context, Widget? child) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ...?widget.actionsBuilder?.call(context),
                TextButton(
                  onPressed: widget.isDefault() ? null : widget.onReset,
                  child: Text(l10n.commonReset),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.listenable,
        builder: (BuildContext context, Widget? child) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth >= 720) {
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: widget.previewBuilder(
                        showToolbar: true,
                        bottomPadding: 0,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          _tabBar(tabController),
                          Expanded(
                            child: TabBarView(
                              controller: tabController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: widget.tabViews(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              // 中档时预览约占四成高度（220~360），矮屏（横屏、分屏）上不超过
              // 一半，给标签页留出可用空间；标签栏停在拖动条下方的原位置。
              final previewHeight = math.min(
                (constraints.maxHeight * 0.38).clamp(220.0, 360.0).toDouble(),
                constraints.maxHeight * 0.5,
              );
              return Column(
                children: <Widget>[
                  ?widget.toolbarBuilder?.call(context),
                  Expanded(
                    child: SnapPanel(
                      controller: _panel,
                      halfExtent:
                          constraints.maxHeight -
                          previewHeight +
                          SnapPanel.handleExtent,
                      background: widget.previewBuilder(
                        showToolbar: false,
                        bottomPadding: SnapPanel.cornerRadius,
                      ),
                      // 收起时点标签：要看这一页的选项了，面板回到中档。
                      header: _tabBar(
                        tabController,
                        onTap: (_) => _panel.reveal(),
                      ),
                      body: TabBarView(
                        controller: tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: <Widget>[
                          for (final view in widget.tabViews())
                            SnapPanelScrollScope(
                              controller: _panel,
                              child: view,
                            ),
                        ],
                      ),
                      handleLabel: l10n.styleEditorPanelHandle,
                      stopLabel: (SnapPanelStop stop) =>
                          _panelStopLabel(l10n, stop),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
