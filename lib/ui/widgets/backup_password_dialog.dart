import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../l10n/app_localizations.dart';
import 'expressive_icon_swap.dart';

/// 密码弹窗的用途：导出时密码可选，导入时用于解开已加密的文件。
enum BackupPasswordPurpose { export, import }

/// 备份与日记文件共用的密码弹窗。
///
/// 返回值：`null` 表示取消整个导出/导入；导出时空串表示不加密。导出会强调
/// 密码无法找回（文件在本机端到端加密）。[confirmLabel] 覆盖默认的确认按钮
/// 文案，供“导出数据”之外的入口（如导出日记文件）使用。
Future<String?> showBackupPasswordDialog(
  BuildContext context, {
  required BackupPasswordPurpose purpose,
  String? confirmLabel,
}) {
  return showDialog<String?>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _BackupPasswordDialog(purpose: purpose, confirmLabel: confirmLabel),
  );
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({required this.purpose, this.confirmLabel});

  final BackupPasswordPurpose purpose;
  final String? confirmLabel;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  String _password = '';
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isExport = widget.purpose == BackupPasswordPurpose.export;
    return AlertDialog(
      title: Text(
        isExport
            ? l10n.dataMgmtExportPasswordTitle
            : l10n.dataMgmtImportPasswordTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              obscureText: _obscureText,
              onChanged: (String value) => _password = value,
              decoration: InputDecoration(
                hintText: isExport
                    ? l10n.dataMgmtExportPasswordHint
                    : l10n.dataMgmtImportPasswordHint,
                suffixIcon: IconButton(
                  tooltip: _obscureText ? l10n.passwordShow : l10n.passwordHide,
                  onPressed: () {
                    setState(() => _obscureText = !_obscureText);
                  },
                  icon: ExpressiveIconSwap(
                    switchKey: _obscureText,
                    child: FaIcon(
                      _obscureText
                          ? FontAwesomeIcons.eyeSlash
                          : FontAwesomeIcons.eye,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
            if (isExport) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                l10n.dataMgmtExportPasswordWarning,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(_password),
          child: Text(
            widget.confirmLabel ??
                (isExport ? l10n.dataMgmtExport : l10n.dataMgmtImportAction),
          ),
        ),
      ],
    );
  }
}
