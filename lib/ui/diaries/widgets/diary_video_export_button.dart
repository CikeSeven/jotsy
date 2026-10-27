import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_export_controller.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';

import '../../widgets/app_modal/app_dialog.dart';

/// 弹出二次确认后才授权 controller 保存，取消及页面退出均不会触发导出。
/// 桌面没有相册，点按直接弹出“另存为…”对话框（对话框即确认）。
class DiaryVideoExportButton extends StatefulWidget {
  const DiaryVideoExportButton({
    super.key,
    required this.video,
    required this.controller,
  });
  final DiaryFileAttachment video;
  final DiaryVideoExportController controller;

  @override
  State<DiaryVideoExportButton> createState() => _DiaryVideoExportButtonState();
}

class _DiaryVideoExportButtonState extends State<DiaryVideoExportButton> {
  Future<void> _saveAs() async {
    final video = widget.video;
    final l10n = context.l10n;
    final result = await widget.controller.saveAs(
      video.path,
      fileName: video.displayName,
      dialogTitle: l10n.desktopSaveVideoDialogTitle,
    );
    if (!mounted || video.path != widget.video.path) return;
    final path = result.path;
    final failure = result.failure;
    if (path == null && failure == null) return;
    _showResult(
      path != null ? l10n.desktopSavedTo(path) : _failureText(failure!),
    );
  }

  String _failureText(VideoExportFailure failure) {
    final l10n = context.l10n;
    return switch (failure) {
      VideoExportFailure.missingFile => l10n.videoExportFileMissing,
      VideoExportFailure.permissionDenied => l10n.videoExportPermissionDenied,
      VideoExportFailure.notEnoughSpace => l10n.videoExportNotEnoughSpace,
      VideoExportFailure.unsupportedFormat => l10n.videoExportUnsupportedFormat,
      VideoExportFailure.downloadFailed => l10n.videoExportDownloadFailed,
      VideoExportFailure.failed => l10n.videoExportFailed,
    };
  }

  void _showResult(String message) {
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }

  Future<void> _confirmExport() async {
    final controller = widget.controller;
    final video = widget.video;
    if (!controller.beginConfirmation()) return;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.videoExportConfirmTitle),
          content: Text(l10n.videoExportConfirmMessage(video.displayName)),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colors.primary),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted || video.path != widget.video.path) {
      controller.cancelConfirmation();
      return;
    }
    final failure = await controller.export(video.path);
    if (!mounted || video.path != widget.video.path) return;
    _showResult(
      failure == null ? context.l10n.videoExportSuccess : _failureText(failure),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    // 导出较快时不闪等待指示：超过 300ms 才换成指示器，两者缩放淡入切换。
    builder: (context, _) => SizedBox.square(
      dimension: 44,
      child: DelayedLoadingGate(
        loading: widget.controller.isExporting,
        builder: (context, showLoading) => ExpressiveIconSwap(
          switchKey: showLoading,
          child: showLoading
              ? Center(
                  child: ExpressiveLoadingIndicator(
                    size: 24,
                    semanticLabel: context.l10n.videoExporting,
                  ),
                )
              : IconButton(
                  tooltip: context.l10n.videoExport,
                  onPressed: widget.controller.isBusy
                      ? null
                      : () => unawaited(
                          AppPlatform.savesImagesToGallery
                              ? _confirmExport()
                              : _saveAs(),
                        ),
                  icon: const FaIcon(FontAwesomeIcons.download, size: 16),
                ),
        ),
      ),
    ),
  );
}
