import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';

/// 新建 / 重命名分区的弹窗：一个名称输入框（按 [TodoSections.normalizeName]
/// 规整，为空或与原名相同时不能保存）。返回规整后的名称，取消返回 null。
/// [current] 给出时是重命名。
Future<String?> showTodoSectionNameDialog(
  BuildContext context, {
  String? current,
}) {
  return showAppDialog<String>(
    context: context,
    builder: (BuildContext _) => _SectionNameDialog(current: current),
  );
}

class _SectionNameDialog extends StatefulWidget {
  const _SectionNameDialog({this.current});

  final String? current;

  @override
  State<_SectionNameDialog> createState() => _SectionNameDialogState();
}

class _SectionNameDialogState extends State<_SectionNameDialog> {
  // 控制器跟随对话框生命周期释放：关闭动画期间仍可能重建。
  late final TextEditingController _name = TextEditingController(
    text: widget.current ?? '',
  )..addListener(() => setState(() {}));

  String? get _next {
    final name = TodoSections.normalizeName(_name.text);
    return name == null || name == widget.current ? null : name;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final next = _next;
    if (next != null) Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final renaming = widget.current != null;
    return AlertDialog(
      title: Text(renaming ? l10n.todoSectionRename : l10n.todoSectionNew),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _name,
          autofocus: true,
          maxLength: TodoSections.maxNameLength,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: l10n.todoSectionNameHint),
          onSubmitted: (_) => _submit(),
          contextMenuBuilder: appTextContextMenuBuilder,
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: scheme.primary,
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: _next == null ? null : _submit,
          child: Text(renaming ? l10n.commonSave : l10n.commonCreate),
        ),
      ],
    );
  }
}
