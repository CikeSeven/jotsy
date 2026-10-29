import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

import '../../widgets/app_modal/app_dialog.dart';

/// 编辑选区的链接：工具栏「链接」按钮与桌面的 Ctrl / ⌘ + K（见
/// `DiaryEditor`）共用这一个对话框。确认后恢复打开前的选区再写入，空地址
/// 移除链接；取消或正文已关闭时不改动。
Future<void> editDiaryLink(
  BuildContext context,
  DiaryEditorController controller,
) async {
  final selection = controller.selection;
  if (selection == null) return;
  final initial = controller.selectionAttributes['href'];
  final url = await showAppDialog<String>(
    context: context,
    builder: (context) =>
        _DiaryLinkDialog(initial: initial is String ? initial : ''),
  );
  if (url == null || controller.state.isDisposed) return;
  controller.select(selection);
  controller.format('href', url.isEmpty ? null : url);
}

/// 链接地址对话框，返回规整后的地址（空字符串为移除链接）。输入框的
/// 控制器随对话框自己的生命周期释放：对话框关闭后还要播完退出动画、仍在
/// 重建输入框，在 `showAppDialog` 返回后立即释放会用到已释放的控制器。
class _DiaryLinkDialog extends StatefulWidget {
  const _DiaryLinkDialog({required this.initial});

  final String initial;

  @override
  State<_DiaryLinkDialog> createState() => _DiaryLinkDialogState();
}

class _DiaryLinkDialogState extends State<_DiaryLinkDialog> {
  late final TextEditingController _input = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// 补全协议并校验：只接受 http(s)（须有主机名）、mailto 与 tel。
  void _confirm() {
    var value = _input.text.trim();
    if (value.isNotEmpty) {
      if (!(Uri.tryParse(value)?.hasScheme ?? false)) {
        value = 'https://$value';
      }
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !['https', 'http', 'mailto', 'tel'].contains(uri.scheme) ||
          (['https', 'http'].contains(uri.scheme) && uri.host.isEmpty)) {
        setState(() => _error = context.l10n.diaryEditorInvalidLink);
        return;
      }
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.autoT0024),
      content: TextField(
        controller: _input,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: l10n.diaryEditorLinkUrl,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          child: Text(l10n.commonCancel),
        ),
        TextButton(onPressed: _confirm, child: Text(l10n.commonConfirm)),
      ],
    );
  }
}
