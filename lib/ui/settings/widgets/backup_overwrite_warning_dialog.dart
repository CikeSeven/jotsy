import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/backup_import_models.dart';
import '../../../l10n/app_localizations.dart';

/// 确认按钮的锁定时长：给用户读完后果的时间，也防止上一步的连续点按直接
/// 落到确认上。这是交互锁定计时而非动画时长，不取 ExpressiveMotion token，
/// 也不受“减少动态效果”影响。
const Duration backupOverwriteConfirmDelay = Duration(seconds: 5);

/// 覆盖导入前的严重警告，返回用户是否确认覆盖。
///
/// 警告逐项列出将被永久替换的本机数据（覆盖全部）或被替换的篇数（覆盖已
/// 存在的日记），并建议先备份。error 色的确认按钮在勾选“我已了解”且
/// [backupOverwriteConfirmDelay] 倒计时结束后才可点；取消、点遮罩或返回键都
/// 视为不覆盖。
Future<bool> showBackupOverwriteWarningDialog(
  BuildContext context, {
  required BackupImportMode mode,
  required BackupArchivePreview preview,
}) async {
  assert(mode.overwritesLocalData);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) =>
        BackupOverwriteWarningDialog(mode: mode, preview: preview),
  );
  return confirmed == true;
}

class BackupOverwriteWarningDialog extends StatefulWidget {
  const BackupOverwriteWarningDialog({
    super.key,
    required this.mode,
    required this.preview,
  });

  final BackupImportMode mode;
  final BackupArchivePreview preview;

  @override
  State<BackupOverwriteWarningDialog> createState() =>
      _BackupOverwriteWarningDialogState();
}

class _BackupOverwriteWarningDialogState
    extends State<BackupOverwriteWarningDialog> {
  bool _acknowledged = false;
  int _remainingSeconds = backupOverwriteConfirmDelay.inSeconds;

  /// 每秒递减一次剩余秒数，归零即停；弹窗关闭时在 dispose 中取消。
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _countdown = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final replaceAll = widget.mode == BackupImportMode.replaceAll;
    final locked = _remainingSeconds > 0;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onErrorContainer,
      height: 1.42,
    );
    return AlertDialog(
      icon: FaIcon(
        FontAwesomeIcons.triangleExclamation,
        size: 28,
        color: colorScheme.error,
      ),
      title: Text(
        replaceAll
            ? l10n.backupOverwriteAllTitle
            : l10n.backupOverwriteExistingTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadii.input),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.backupOverwriteIrreversible,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (replaceAll) ...<Widget>[
                      Text(l10n.backupOverwriteAllLead, style: bodyStyle),
                      const SizedBox(height: AppSpacing.xs),
                      for (final item in <String>[
                        l10n.backupOverwriteAllDiaries(
                          widget.preview.localDiaryCount,
                        ),
                        l10n.backupOverwriteAllTags(
                          widget.preview.localTagCount,
                        ),
                        l10n.backupOverwriteAllMedia,
                        l10n.backupOverwriteAllSettings,
                      ])
                        _Bullet(text: item, style: bodyStyle),
                    ] else
                      Text(
                        l10n.backupOverwriteExistingBody(
                          widget.preview.existingDiaryCount,
                        ),
                        style: bodyStyle,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              l10n.backupOverwriteBackupTip,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            // 不用 CheckboxListTile：它的最小高度与标题间距在弹窗里留白过大。
            // 整行可点，MergeSemantics 让读屏把勾选框与文案读成一项。
            MergeSemantics(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.input),
                onTap: () => setState(() => _acknowledged = !_acknowledged),
                child: Row(
                  children: <Widget>[
                    Checkbox(
                      value: _acknowledged,
                      onChanged: (bool? value) {
                        setState(() => _acknowledged = value ?? false);
                      },
                      activeColor: colorScheme.error,
                      checkColor: colorScheme.onError,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s,
                        ),
                        child: Text(
                          l10n.backupOverwriteAcknowledge,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
          onPressed: _acknowledged && !locked
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(
            locked
                ? l10n.backupOverwriteConfirmCountdown(_remainingSeconds)
                : l10n.backupOverwriteConfirm,
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('•', style: style),
          const SizedBox(width: AppSpacing.s),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
