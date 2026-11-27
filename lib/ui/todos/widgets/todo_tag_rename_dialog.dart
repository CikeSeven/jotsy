import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';

/// 给待办标签改名的弹窗：一个名称输入框（按 [TodoTags.normalize] 规整，
/// 规整后为空或与原名完全相同时不能保存），下面一行说明“改成已有的标签名
/// 会把两个标签合并”。返回规整后的新名称，取消返回 null。
Future<String?> showTodoTagRenameDialog(
  BuildContext context, {
  required String current,
}) {
  return showAppDialog<String>(
    context: context,
    builder: (BuildContext _) => _RenameDialog(current: current),
  );
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.current});

  final String current;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  // 控制器跟随对话框生命周期释放：关闭动画期间仍可能重建。
  late final TextEditingController _name = TextEditingController(
    text: widget.current,
  )..addListener(() => setState(() {}));

  String? get _next {
    final name = TodoTags.normalize(_name.text);
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
    return AlertDialog(
      title: Text(l10n.todoTagRename),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: TodoTags.maxLength,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(prefixText: '@'),
              onSubmitted: (_) => _submit(),
              contextMenuBuilder: appTextContextMenuBuilder,
            ),
            Text(
              l10n.todoTagRenameHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
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
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
