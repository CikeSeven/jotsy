import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/widgets/diary_floating_toolbar_surface.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../controllers/mind_map_editing_controller.dart';

/// 画布底部的浮动工具坞（材质与编辑器的悬浮工具栏同一套）。
///
/// 两组按钮随选中状态切换（在同一块不透明表面里交叉淡化，表面本身不淡）：
/// - 没选中：添加主题（加在根下）、结构与样式、适应屏幕；
/// - 选中节点：子主题、同级主题、编辑文字、收起 / 展开、删除（根不能删）。
/// 窄屏放不下时横向滚动（桌面可拖动 / Shift + 滚轮）。
class MindMapDock extends StatelessWidget {
  const MindMapDock({
    super.key,
    required this.controller,
    required this.onOpenStyle,
    required this.onFit,
  });

  final MindMapEditingController controller;
  final VoidCallback onOpenStyle;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final selected = controller.selectedId;
        final node = selected == null
            ? null
            : controller.document.index[selected];
        final isRoot = selected == controller.document.root.id;
        final List<Widget> buttons = node == null
            ? <Widget>[
                _DockButton(
                  icon: FontAwesomeIcons.plus,
                  label: l10n.mindMapAddTopic,
                  onPressed: () => controller.addChild(
                    parentId: controller.document.root.id,
                  ),
                ),
                _DockButton(
                  icon: FontAwesomeIcons.palette,
                  label: l10n.mindMapStyle,
                  onPressed: onOpenStyle,
                ),
                _DockButton(
                  icon: FontAwesomeIcons.expand,
                  label: l10n.mindMapFit,
                  onPressed: onFit,
                ),
              ]
            : <Widget>[
                _DockButton(
                  icon: FontAwesomeIcons.diagramSuccessor,
                  label: l10n.mindMapAddChild,
                  onPressed: () => controller.addChild(),
                ),
                _DockButton(
                  icon: FontAwesomeIcons.diagramNext,
                  label: l10n.mindMapAddSibling,
                  onPressed: () => controller.addSibling(),
                ),
                _DockButton(
                  icon: FontAwesomeIcons.pen,
                  label: l10n.mindMapEditText,
                  onPressed: () => controller.startEditing(node.id),
                ),
                _DockButton(
                  icon: node.collapsed
                      ? FontAwesomeIcons.upRightAndDownLeftFromCenter
                      : FontAwesomeIcons.downLeftAndUpRightToCenter,
                  label: node.collapsed
                      ? l10n.mindMapExpand
                      : l10n.mindMapCollapse,
                  onPressed: node.children.isEmpty
                      ? null
                      : () => controller.toggleCollapsed(node.id),
                ),
                _DockButton(
                  icon: FontAwesomeIcons.palette,
                  label: l10n.mindMapStyle,
                  onPressed: onOpenStyle,
                ),
                _DockButton(
                  icon: FontAwesomeIcons.trashCan,
                  label: l10n.mindMapDelete,
                  destructive: true,
                  onPressed: isRoot ? null : controller.deleteSelected,
                ),
              ];
        return DiaryFloatingToolbarSurface(
          child: DesktopHorizontalScroll(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: AnimatedSwitcher(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.fast,
                ),
                switchInCurve: ExpressiveMotion.effects,
                switchOutCurve: ExpressiveMotion.exit,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.center,
                  children: <Widget>[...previous, ?current],
                ),
                child: Row(
                  key: ValueKey<bool>(node == null),
                  mainAxisSize: MainAxisSize.min,
                  children: buttons,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final color = !enabled
        ? scheme.onSurface.withValues(alpha: 0.32)
        : destructive
        ? scheme.error
        : scheme.onSurface;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 60,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FaIcon(icon, size: 16, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
