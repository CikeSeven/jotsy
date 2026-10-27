import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/app_modal/app_dialog.dart';

/// 删除导入字体前的确认；右侧删除按钮为危险色。返回 true 表示确认删除。
Future<bool> showDiaryFontDeleteDialog(
  BuildContext context, {
  required String fontName,
}) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final colorScheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(l10n.diaryTypographyDeleteFontTitle(fontName)),
        content: Text(l10n.diaryTypographyDeleteFontMessage),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
