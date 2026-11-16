import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../controllers/mind_map_editing_controller.dart';

/// 导图全屏页（导图日记的编辑页、嵌入导图的编辑页与查看页）共用的外框：
/// 编辑区背景、顶栏（返回 + 标题 + 撤销 / 重做 + 宿主给的动作）。
///
/// 顶栏是玻璃时画布铺到顶栏之下（玻璃透出导图），[body] 拿到被顶栏盖住的
/// 高度作为 `topInset`；经典顶栏时画布从顶栏下沿开始，`topInset` 为 0。
class MindMapPageScaffold extends StatelessWidget {
  const MindMapPageScaffold({
    super.key,
    required this.title,
    required this.onBack,
    required this.body,
    this.controller,
    this.actions = const <Widget>[],
    this.overlay,
    this.paintBackground = true,
  });

  final Widget title;
  final VoidCallback onBack;

  /// 给出时顶栏带撤销 / 重做。
  final MindMapEditingController? controller;
  final List<Widget> actions;
  final Widget Function(BuildContext context, double topInset) body;

  /// 盖在整页之上的一层（信息面板、加载遮罩等）。
  final Widget? overlay;

  /// 是否自己画编辑区背景；宿主外面已经画了（日记编辑页）时传 false。
  final bool paintBackground;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final glass = AppGlass.of(context).isGlass(AppGlassComponent.topBars);
    final controller = this.controller;
    final page = Builder(
      builder: (BuildContext context) {
        final topInset = glass ? MediaQuery.paddingOf(context).top + 64 : 0.0;
        return Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          extendBodyBehindAppBar: glass,
          resizeToAvoidBottomInset: false,
          appBar: AppTopBar(
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: onBack,
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
            title: title,
            actions: <Widget>[
              if (controller != null)
                ListenableBuilder(
                  listenable: controller,
                  builder: (BuildContext context, Widget? _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: l10n.mindMapUndo,
                        onPressed: controller.canUndo ? controller.undo : null,
                        icon: const FaIcon(
                          FontAwesomeIcons.arrowRotateLeft,
                          size: 16,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.mindMapRedo,
                        onPressed: controller.canRedo ? controller.redo : null,
                        icon: const FaIcon(
                          FontAwesomeIcons.arrowRotateRight,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ...actions,
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[body(context, topInset), ?overlay],
          ),
        );
      },
    );
    return paintBackground
        ? AppPageBackground(area: AppBackgroundArea.editor, child: page)
        : page;
  }
}
