import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/app_modal/app_dialog.dart';

/// 设备名的长度上限（DESIGN.md §5.27）。
const int kLanSyncDeviceNameMaxLength = 40;

/// 修改名称的对话框（只负责收集输入）：本机设备名与已配对设备的备注名共用。
///
/// 确认返回去除首尾空白后的新名称；取消、点遮罩或名称没有变化时返回 null。
/// [allowEmpty] 为 false（设备名）时名称为空则确认键不可点；为 true（备注名，
/// 留空即清除）时可以确认空名，返回空串。[title] / [hintText] 缺省为设备名
/// 的文案。
Future<String?> showLanSyncRenameDialog(
  BuildContext context, {
  required String initialName,
  String? title,
  String? hintText,
  bool allowEmpty = false,
}) => showAppDialog<String>(
  context: context,
  builder: (_) => _LanSyncRenameDialog(
    initialName: initialName,
    title: title,
    hintText: hintText,
    allowEmpty: allowEmpty,
  ),
);

/// 输入控制器由对话框自己持有并释放：`showAppDialog` 的 Future 在路由 pop
/// 时就完成，退场动画期间输入框仍在树上。
class _LanSyncRenameDialog extends StatefulWidget {
  const _LanSyncRenameDialog({
    required this.initialName,
    required this.title,
    required this.hintText,
    required this.allowEmpty,
  });

  final String initialName;
  final String? title;
  final String? hintText;
  final bool allowEmpty;

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
    if (name.isEmpty && !widget.allowEmpty) return;
    Navigator.of(context).pop(name == widget.initialName.trim() ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title ?? l10n.lanSyncRenameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: kLanSyncDeviceNameMaxLength,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: widget.hintText ?? l10n.lanSyncRenameHint,
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
            textStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          onPressed: _trimmed.isEmpty && !widget.allowEmpty ? null : _submit,
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
