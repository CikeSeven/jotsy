import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_ops.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/widgets/diary_floating_toolbar_surface.dart';
import '../controllers/mind_map_editing_controller.dart';
import 'mind_map_format_bar.dart';

/// 手机上编辑主题文字时键盘上方的附件条（画布与大纲各一种），同一块浮动
/// 卡片里两行：上行是格式条 [MindMapFormatBar]，下行是操作。
///
/// - 画布：子主题、同级、换行、删除、完成；
/// - 大纲：取消缩进、缩进、上移、下移、删除、完成。
///
/// 删除与工具坞的删除一致（`deleteSelected`，选中相邻的主题，可撤销），但
/// 接着编辑新选中的主题、键盘不收起；中心主题不能删、按钮置灰。画布让正在编辑的节点露在附件条之上
/// 时按 [height] 留白（见 MindMapCanvas 的 `_revealPadding`）。
abstract final class MindMapAccessoryBar {
  /// 操作行的高度。
  static const double actionsHeight = 52;

  /// 附件条连同与键盘之间的间距的总高度。
  static const double height =
      MindMapFormatBar.height + actionsHeight + _bottomGap;

  static const double _bottomGap = 8;
}

/// 画布上编辑文字时的附件条。
class MindMapEditingAccessoryBar extends StatelessWidget {
  const MindMapEditingAccessoryBar({super.key, required this.controller});

  final MindMapEditingController controller;

  void _insertNewLine() {
    final primary = FocusManager.instance.primaryFocus?.context;
    final editable = primary?.findAncestorStateOfType<EditableTextState>();
    if (editable == null) return;
    final value = editable.textEditingValue;
    final selection = value.selection;
    if (!selection.isValid) return;
    final text = value.text.replaceRange(selection.start, selection.end, '\n');
    editable.userUpdateTextEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: selection.start + 1),
      ),
      SelectionChangedCause.keyboard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _AccessoryCard(
      controller: controller,
      actions: <Widget>[
        _AccessoryAction(
          icon: FontAwesomeIcons.diagramSuccessor,
          label: l10n.mindMapAddChild,
          onTap: () => controller.addChild(),
        ),
        _AccessoryAction(
          icon: FontAwesomeIcons.diagramNext,
          label: l10n.mindMapAddSibling,
          onTap: () => controller.addSibling(),
        ),
        _AccessoryAction(
          icon: FontAwesomeIcons.turnDown,
          label: l10n.mindMapNewLine,
          onTap: _insertNewLine,
        ),
        _DeleteAction(controller: controller),
        _AccessoryAction(
          icon: FontAwesomeIcons.check,
          label: l10n.mindMapDone,
          onTap: controller.stopEditing,
        ),
      ],
    );
  }
}

/// 大纲里编辑文字时的附件条。
class MindMapOutlineAccessoryBar extends StatelessWidget {
  const MindMapOutlineAccessoryBar({super.key, required this.controller});

  final MindMapEditingController controller;

  void _apply(MindMapDocument Function(MindMapDocument, String) op) {
    final id = controller.editingId;
    if (id == null) return;
    controller.commit(op(controller.document, id), select: id);
    controller.startEditing(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _AccessoryCard(
      controller: controller,
      actions: <Widget>[
        _AccessoryAction(
          icon: FontAwesomeIcons.outdent,
          label: l10n.mindMapOutdent,
          onTap: () => _apply(MindMapOps.outdent),
        ),
        _AccessoryAction(
          icon: FontAwesomeIcons.indent,
          label: l10n.mindMapIndent,
          onTap: () => _apply(MindMapOps.indent),
        ),
        _AccessoryAction(
          icon: FontAwesomeIcons.arrowUp,
          label: l10n.mindMapMoveUp,
          onTap: () => _apply(
            (document, id) => MindMapOps.shift(document, id, up: true),
          ),
        ),
        _AccessoryAction(
          icon: FontAwesomeIcons.arrowDown,
          label: l10n.mindMapMoveDown,
          onTap: () => _apply(
            (document, id) => MindMapOps.shift(document, id, up: false),
          ),
        ),
        _DeleteAction(controller: controller),
        _AccessoryAction(
          icon: FontAwesomeIcons.check,
          label: l10n.mindMapDone,
          onTap: controller.stopEditing,
        ),
      ],
    );
  }
}

/// 两行的浮动卡片：格式条 + 操作行。
class _AccessoryCard extends StatelessWidget {
  const _AccessoryCard({required this.controller, required this.actions});

  final MindMapEditingController controller;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, MindMapAccessoryBar._bottomGap),
    child: DiaryFloatingToolbarSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MindMapFormatBar(controller: controller),
            SizedBox(
              height: MindMapAccessoryBar.actionsHeight,
              child: Row(children: actions),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AccessoryAction extends StatelessWidget {
  const _AccessoryAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback? onTap;

  /// 图标与文字的颜色；缺省为表面上的文字色。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = color ?? theme.colorScheme.onSurface;
    final ink = onTap == null ? base.withValues(alpha: 0.38) : base;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FaIcon(icon, size: 15, color: ink),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: ink,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 删除正在编辑的主题（中心主题置灰）。
class _DeleteAction extends StatelessWidget {
  const _DeleteAction({required this.controller});

  final MindMapEditingController controller;

  @override
  Widget build(BuildContext context) {
    final id = controller.editingId ?? controller.selectedId;
    final isRoot = id == null || id == controller.document.root.id;
    return _AccessoryAction(
      icon: FontAwesomeIcons.trashCan,
      label: context.l10n.mindMapDelete,
      color: Theme.of(context).colorScheme.error,
      // 删掉后接着编辑相邻的主题，键盘不收起。
      onTap: isRoot
          ? null
          : () {
              controller.select(id);
              controller.deleteSelected(keepEditing: true);
            },
    );
  }
}
