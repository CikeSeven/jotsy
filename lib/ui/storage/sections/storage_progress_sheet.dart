import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/storage/media_compressor.dart';
import '../../../core/services/storage/storage_media_service.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../../settings/widgets/app_update_progress_bar.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../controllers/storage_busy_messages.dart';
import '../viewmodels/storage_media_view.dart';

/// 压缩进度面板：打开即开始，显示总进度、第几项与文件名，可取消（已完成的
/// 照样保存）；结束后原地换成结果（压缩了几项、省了多少、几项没变小或失败）。
///
/// 运行期间不能下拉、点外面或按返回关闭：压缩完要一次改写引用，中途离开
/// 会让人以为已经停止。返回结果；守卫拒绝（有编辑页 / 撤销窗口）时返回 null。
Future<StorageCompressResult?> showStorageCompressProgress(
  BuildContext context, {
  required StorageMediaService service,
  required List<StorageMediaEntry> entries,
  required StorageCompressContext choice,
}) => showAppModalBottomSheet<StorageCompressResult>(
  context: context,
  isDismissible: false,
  enableDrag: false,
  builder: (BuildContext context) =>
      _ProgressSheet(service: service, entries: entries, choice: choice),
);

class _ProgressSheet extends StatefulWidget {
  const _ProgressSheet({
    required this.service,
    required this.entries,
    required this.choice,
  });

  final StorageMediaService service;
  final List<StorageMediaEntry> entries;
  final StorageCompressContext choice;

  @override
  State<_ProgressSheet> createState() => _ProgressSheetState();
}

class _ProgressSheetState extends State<_ProgressSheet> {
  final StorageCancelToken _cancel = StorageCancelToken();
  StorageCompressProgress? _progress;
  StorageCompressResult? _result;
  StorageBusyReason? _busy;
  bool _cancelling = false;

  bool get _finished => _result != null || _busy != null;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final result = await widget.service.compressMedia(
        widget.entries,
        imagePreset: widget.choice.imagePreset,
        videoPreset: widget.choice.videoPreset,
        cancel: _cancel,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) setState(() => _result = result);
    } on StorageBusyException catch (error) {
      if (mounted) setState(() => _busy = error.reason);
    }
  }

  void _requestCancel() {
    setState(() => _cancelling = true);
    _cancel.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _finished,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.l,
          ),
          child: AnimatedSize(
            duration: ExpressiveMotion.duration(
              context,
              ExpressiveMotion.medium,
            ),
            curve: ExpressiveMotion.effects,
            alignment: Alignment.topCenter,
            child: _finished ? _buildResult(context) : _buildRunning(context),
          ),
        ),
      ),
    );
  }

  Widget _buildRunning(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = _progress;
    return Column(
      key: const ValueKey<String>('running'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.storageMgmtCompressing, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.l),
        AppUpdateProgressBar(value: progress?.overall ?? 0),
        const SizedBox(height: AppSpacing.m),
        Text(
          progress == null
              ? l10n.storageMgmtCompressPreparing
              : l10n.storageMgmtCompressStep(
                  progress.index + 1,
                  progress.total,
                  progress.entry.fileName,
                ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
            ),
            onPressed: _cancelling ? null : _requestCancel,
            child: Text(
              _cancelling ? l10n.storageMgmtCancelling : l10n.commonCancel,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = _result;
    final busy = _busy;
    final lines = <String>[
      if (busy != null) storageBusyMessage(l10n, busy),
      if (result != null) ...<String>[
        if (result.compressed > 0)
          l10n.storageMgmtCompressDone(
            result.compressed,
            l10n.formatByteSize(result.savedBytes),
          ),
        if (result.unchanged > 0)
          l10n.storageMgmtCompressUnchanged(result.unchanged),
        if (result.failed > 0) l10n.storageMgmtCompressFailed(result.failed),
        if (result.skippedRows > 0)
          l10n.storageMgmtSkippedRows(result.skippedRows),
        if (result.compressed == 0 &&
            result.unchanged == 0 &&
            result.failed == 0)
          l10n.storageMgmtCompressNoneDone,
      ],
    ];
    final ok = result != null && result.compressed > 0;
    return Column(
      key: const ValueKey<String>('result'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            FaIcon(
              ok ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleInfo,
              size: 20,
              color: ok ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                result?.cancelled ?? false
                    ? l10n.storageMgmtCompressCancelled
                    : l10n.storageMgmtCompressFinished,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(line, style: theme.textTheme.bodyMedium),
          ),
        const SizedBox(height: AppSpacing.l),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(result),
            child: Text(l10n.storageMgmtDone),
          ),
        ),
      ],
    );
  }
}
