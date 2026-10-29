import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/app_modal/app_dialog.dart';

/// 设备名的长度上限（DESIGN.md §5.27）。
const int kLanSyncDeviceNameMaxLength = 40;

/// 修改本机设备名的对话框（只负责收集输入）。
///
/// 确认返回去除首尾空白后的新名称；取消、点遮罩或名称没有变化时返回 null。
/// 名称为空时确认键不可点。
Future<String?> showLanSyncRenameDialog(
  BuildContext context, {
  required String initialName,
}) => showAppDialog<String>(
  context: context,
  builder: (_) => _LanSyncRenameDialog(initialName: initialName),
);

/// 输入控制器由对话框自己持有并释放：`showAppDialog` 的 Future 在路由 pop
/// 时就完成，退场动画期间输入框仍在树上。
class _LanSyncRenameDialog extends StatefulWidget {
  const _LanSyncRenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_LanSyncRenameDialog> createState() => _LanSyncRenameDialogState();
}

class _LanSyncRenameDialogState extends State<_LanSyncRenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _trimmed => _controller.text.trim();

  void _submit() {
    final name = _trimmed;
    if (name.isEmpty) return;
    Navigator.of(context).pop(name == widget.initialName.trim() ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.lanSyncRenameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: kLanSyncDeviceNameMaxLength,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: l10n.lanSyncRenameHint,
          counterText: '',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: _trimmed.isEmpty ? null : _submit,
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
