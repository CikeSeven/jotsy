import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../sections/todo_section_callbacks.dart';

/// 分区标题行尾：“+”（在这个分区里新建）与 ⋮ 菜单（重命名、上移、下移、
/// 删除；挪到头的那一项停用）。
class TodoSectionHeaderActions extends StatelessWidget {
  const TodoSectionHeaderActions({
    super.key,
    required this.section,
    required this.callbacks,
  });

  final TodoSection section;
  final TodoSectionCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = callbacks.sections;
    final index = sections.indexWhere((s) => s.id == section.id);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: l10n.todoSectionAddTo(section.name),
          visualDensity: VisualDensity.compact,
          onPressed: () => callbacks.onAddTodo(section),
          icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
        ),
        ExpressiveMenuButton(
          tooltip: l10n.todoSectionActions,
          icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 14),
          items: <Widget>[
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.pen),
              onPressed: () => callbacks.onRename(section),
              child: Text(l10n.todoSectionRename),
            ),
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.arrowUp),
              onPressed: index > 0 ? () => callbacks.onMove(section, -1) : null,
              child: Text(l10n.todoSectionMoveUp),
            ),
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.arrowDown),
              onPressed: index >= 0 && index < sections.length - 1
                  ? () => callbacks.onMove(section, 1)
                  : null,
              child: Text(l10n.todoSectionMoveDown),
            ),
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
              destructive: true,
              onPressed: () => callbacks.onDelete(section),
              child: Text(l10n.todoSectionDelete),
            ),
          ],
        ),
      ],
    );
  }
}
