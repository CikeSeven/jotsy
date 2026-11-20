import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/floating_top_bar/floating_island.dart';
import '../controllers/mind_map_editing_controller.dart';

/// 浮岛顶栏中间的“画布 / 大纲”切换：一颗岛里两个图标（`sitemap` 画布、
/// `listUl` 大纲），选中的那一格垫 `secondaryContainer` 圆底，切换时圆底
/// 横向滑过去（`medium` / `spatial`，减少动画时直接到位），图标颜色同步过渡。
///
/// 切换前先结束文字编辑（与原来工作区里的切换一致）；视图存在会话
/// [MindMapEditingController.outlineView] 里，工作区与导出面板据此。
class MindMapViewSwitch extends StatelessWidget {
  const MindMapViewSwitch({super.key, required this.controller});

  static const double _cell = 40;
  static const double _padding = 4;

  /// 整颗岛的宽度；顶栏中间放不下时由宿主改放进“更多”。
  static const double width = _cell * 2 + _padding * 2;

  final MindMapEditingController controller;

  void _select(bool outline) {
    if (controller.outlineView == outline) return;
    controller.stopEditing();
    controller.outlineView = outline;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    return FloatingIsland(
      padding: const EdgeInsets.symmetric(horizontal: _padding),
      child: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? _) {
          final outline = controller.outlineView;
          Widget cell(bool value, FaIconData icon, String tooltip) {
            final selected = value == outline;
            return Semantics(
              selected: selected,
              inMutuallyExclusiveGroup: true,
              child: IconButton(
                tooltip: tooltip,
                onPressed: () => _select(value),
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(_cell),
                  minimumSize: const Size.square(_cell),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: selected
                        ? colors.onSecondaryContainer
                        : colors.onSurfaceVariant,
                  ),
                  duration: duration,
                  curve: ExpressiveMotion.effects,
                  builder: (BuildContext context, Color? color, Widget? _) =>
                      FaIcon(icon, size: 16, color: color),
                ),
              ),
            );
          }

          // 只在竖直方向居中：横向不撑开，岛就是两格的宽度。
          return Center(
            widthFactor: 1,
            child: SizedBox(
              width: _cell * 2,
              height: _cell,
              child: Stack(
                children: <Widget>[
                  AnimatedAlign(
                    alignment: outline
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    duration: duration,
                    curve: ExpressiveMotion.spatial,
                    child: SizedBox.square(
                      dimension: _cell,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: const CircleBorder(),
                          color: colors.secondaryContainer,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      cell(
                        false,
                        FontAwesomeIcons.sitemap,
                        l10n.mindMapCanvasView,
                      ),
                      cell(true, FontAwesomeIcons.listUl, l10n.mindMapOutline),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
