import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/expressive_menu/expressive_menu.dart';

/// 桌面上待办行的右键菜单（4 项单行动作，经 [ExpressiveMenuAnchor.openAt]
/// 在指针处打开）：完成 / 恢复、改到今天、移到清单…、删除。
///
/// 只在桌面挂上（调用方按 `AppPlatform.isDesktop` 决定）；手机上的同类操作
/// 走左右滑与长按多选。
class TodoTileContextMenu extends StatelessWidget {
  const TodoTileContextMenu({
    super.key,
    required this.done,
    required this.onToggle,
    required this.onMoveToToday,
    required this.onMoveToList,
    required this.onDelete,
    required this.child,
  });

  final bool done;
  final VoidCallback onToggle;
  final VoidCallback onMoveToToday;
  final VoidCallback onMoveToList;
  final VoidCallback onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpressiveMenuAnchor(
      menuChildren: <Widget>[
        ExpressiveMenuItem(
          leadingIcon: FaIcon(
            done ? FontAwesomeIcons.rotateLeft : FontAwesomeIcons.circleCheck,
          ),
          onPressed: onToggle,
          child: Text(done ? l10n.todoMarkUndone : l10n.todoMarkDone),
        ),
        if (!done)
          ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.solidSun),
            onPressed: onMoveToToday,
            child: Text(l10n.todoMoveToToday),
          ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.folderOpen),
          onPressed: onMoveToList,
          child: Text(l10n.todoMoveToList),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
          destructive: true,
          onPressed: onDelete,
          child: Text(l10n.todoDelete),
        ),
      ],
      builder:
          (BuildContext context, ExpressiveMenuAnchorState menu, Widget? row) =>
              GestureDetector(
                onSecondaryTapUp: (TapUpDetails details) =>
                    menu.openAt(details.globalPosition),
                child: row,
              ),
      child: child,
    );
  }
}
