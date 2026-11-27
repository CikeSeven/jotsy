import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/reorder_handle.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../widgets/todo_check_box.dart';
import 'todo_bare_input.dart';

/// 详情里的一步：48dp 方框格 + 可直接改的标题 + “⋯”菜单（转为独立待办、
/// 删除）+ 拖动手柄（第 [index] 项）。勾掉的标题变灰并加删除线。标题在
/// 失去焦点或回车时经 [onRename] 提交；别处改了标题（同步、撤销）而这里
/// 没在编辑时跟上。
class TodoStepRow extends StatefulWidget {
  const TodoStepRow({
    super.key,
    required this.step,
    required this.index,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    required this.onConvert,
  });

  final TodoStep step;
  final int index;
  final VoidCallback onToggle;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;
  final VoidCallback onConvert;

  @override
  State<TodoStepRow> createState() => _TodoStepRowState();
}

class _TodoStepRowState extends State<TodoStepRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.step.title,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onRename(_controller.text);
    });
  }

  @override
  void didUpdateWidget(covariant TodoStepRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.step.title != _controller.text) {
      _controller.text = widget.step.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final done = widget.step.done;
    return Row(
      children: <Widget>[
        Semantics(
          checked: done,
          button: true,
          label: done ? l10n.todoMarkUndone : l10n.todoMarkDone,
          excludeSemantics: true,
          child: InkResponse(
            onTap: widget.onToggle,
            radius: 20,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(child: TodoCheckBoxVisual(checked: done, size: 18)),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            maxLength: TodoStep.maxTitleLength,
            textInputAction: TextInputAction.done,
            onSubmitted: widget.onRename,
            contextMenuBuilder: appTextContextMenuBuilder,
            style: TextStyle(
              color: done ? scheme.onSurfaceVariant : null,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: scheme.onSurfaceVariant,
            ),
            decoration: todoBareInputDecoration(),
          ),
        ),
        ExpressiveMenuButton(
          tooltip: l10n.todoStepActions,
          icon: const FaIcon(FontAwesomeIcons.ellipsis, size: 14),
          items: <Widget>[
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(
                FontAwesomeIcons.arrowUpRightFromSquare,
              ),
              onPressed: widget.onConvert,
              child: Text(l10n.todoStepToTodo),
            ),
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
              destructive: true,
              onPressed: widget.onDelete,
              child: Text(l10n.todoStepDelete),
            ),
          ],
        ),
        ReorderHandle(index: widget.index, semanticLabel: l10n.todoStepReorder),
      ],
    );
  }
}
