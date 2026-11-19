import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/floating_top_bar/floating_action_island.dart';
import '../../widgets/floating_top_bar/floating_island.dart';
import '../../widgets/floating_top_bar/floating_top_bar.dart';
import '../../widgets/floating_top_bar/floating_top_bar_host.dart';
import '../controllers/mind_map_editing_controller.dart';

/// 导图全屏页（导图日记的编辑页、嵌入导图的编辑页与查看页）共用的外框：
/// 编辑区背景与浮岛顶栏（返回岛 + 导图名 + 撤销 / 重做与宿主给的动作）。
///
/// 画布铺满整页，浮岛压在画布上（不画整条栏），[body] 拿到被状态栏与浮岛
/// 盖住的高度作为 `topInset`，据此把适配视图与大纲留在岛的下面。
class MindMapPageScaffold extends StatelessWidget {
  const MindMapPageScaffold({
    super.key,
    required this.title,
    required this.onBack,
    required this.body,
    this.controller,
    this.actions = const <Widget>[],
    this.paintBackground = true,
  });

  final Widget title;
  final VoidCallback onBack;

  /// 给出时动作胶囊带撤销 / 重做。
  final MindMapEditingController? controller;

  /// 动作胶囊里撤销 / 重做之后的按钮（图标按钮、“更多”、主色文字胶囊）。
  final List<Widget> actions;
  final Widget Function(BuildContext context, double topInset) body;

  /// 是否自己画编辑区背景；宿主外面已经画了（日记编辑页）时传 false。
  final bool paintBackground;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = this.controller;
    final page = Builder(
      builder: (BuildContext context) {
        final topInset =
            MediaQuery.viewPaddingOf(context).top + FloatingTopBar.extent;
        return Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          resizeToAvoidBottomInset: false,
          body: FloatingTopBarHost(
            statusBarColor: AppPageBackdrop.solidBarColorOf(context),
            leading: FloatingBackIsland(onPressed: onBack),
            middle: FloatingIslandLabel(child: title),
            trailing: FloatingActionIsland(
              children: <Widget>[
                if (controller != null)
                  ListenableBuilder(
                    listenable: controller,
                    builder: (BuildContext context, Widget? _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: l10n.mindMapUndo,
                          onPressed: controller.canUndo
                              ? controller.undo
                              : null,
                          icon: const FaIcon(
                            FontAwesomeIcons.arrowRotateLeft,
                            size: 16,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.mindMapRedo,
                          onPressed: controller.canRedo
                              ? controller.redo
                              : null,
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
            child: SizedBox.expand(child: body(context, topInset)),
          ),
        );
      },
    );
    return paintBackground
        ? AppPageBackground(area: AppBackgroundArea.editor, child: page)
        : page;
  }
}
