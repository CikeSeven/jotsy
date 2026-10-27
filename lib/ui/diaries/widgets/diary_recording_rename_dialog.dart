import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/app_modal/app_dialog.dart';

/// 录音重命名弹窗，录音面板与正文播放器共用。
///
/// 确认返回去除首尾空白后的名称（可能为空串，由调用方决定回退到默认标题），
/// 取消或点击遮罩返回 `null`。
Future<String?> showDiaryRecordingRenameDialog(
  BuildContext context, {
  required String initialName,
}) => showAppDialog<String>(
  context: context,
  builder: (_) => _RecordingRenameDialog(initialName: initialName),
);

/// 输入控制器必须由弹窗自己持有并释放：`showDialog` 的 Future 在路由 pop 时就
/// 完成，而退场动画期间输入框仍在树上，若在调用方 `await` 之后立刻 dispose，
/// 会触发“控制器已释放仍被使用”。
class _RecordingRenameDialog extends StatefulWidget {
  const _RecordingRenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RecordingRenameDialog> createState() => _RecordingRenameDialogState();
}

class _RecordingRenameDialogState extends State<_RecordingRenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.recordingRename),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        decoration: InputDecoration(
          hintText: l10n.recordingNameHint,
          counterText: '',
        ),
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
          onPressed: _submit,
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
