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

/// 导出正文视频：手机上弹出二次确认后才授权 [controller] 保存到相册，桌面
/// 没有相册，直接弹出“另存为…”对话框（对话框即确认）；结果经
/// [HomeHintVisibilityScope.showTrackedSnackBar] 提示。取消、页面退出或视频
/// 换了都不提示。导出按钮与视频菜单的“保存到相册”共用这一条（#252）。
Future<void> runDiaryVideoExport(
  BuildContext context, {
  required DiaryFileAttachment video,
  required DiaryVideoExportController controller,
}) => AppPlatform.savesImagesToGallery
    ? _confirmExport(context, video, controller)
    : _saveAs(context, video, controller);

Future<void> _saveAs(
  BuildContext context,
  DiaryFileAttachment video,
  DiaryVideoExportController controller,
) async {
  final l10n = context.l10n;
  final result = await controller.saveAs(
    video.path,
    fileName: video.displayName,
    dialogTitle: l10n.desktopSaveVideoDialogTitle,
  );
  if (!context.mounted) return;
  final path = result.path;
  final failure = result.failure;
  if (path == null && failure == null) return;
  _showResult(
    context,
    path != null ? l10n.desktopSavedTo(path) : _failureText(l10n, failure!),
  );
}

String _failureText(AppLocalizations l10n, VideoExportFailure failure) =>
    switch (failure) {
      VideoExportFailure.missingFile => l10n.videoExportFileMissing,
      VideoExportFailure.permissionDenied => l10n.videoExportPermissionDenied,
      VideoExportFailure.notEnoughSpace => l10n.videoExportNotEnoughSpace,
      VideoExportFailure.unsupportedFormat => l10n.videoExportUnsupportedFormat,
      VideoExportFailure.downloadFailed => l10n.videoExportDownloadFailed,
      VideoExportFailure.failed => l10n.videoExportFailed,
    };

void _showResult(BuildContext context, String message) {
  unawaited(
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(message)),
    ),
  );
}

Future<void> _confirmExport(
  BuildContext context,
  DiaryFileAttachment video,
  DiaryVideoExportController controller,
) async {
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
  if (confirmed != true || !context.mounted) {
    controller.cancelConfirmation();
    return;
  }
  final failure = await controller.export(video.path);
  if (!context.mounted) return;
  _showResult(
    context,
    failure == null
        ? context.l10n.videoExportSuccess
        : _failureText(context.l10n, failure),
  );
}

/// 导出按钮（下载图标）：流程见 [runDiaryVideoExport]。导出超过 300ms 时
/// 换成等待指示。
class DiaryVideoExportButton extends StatelessWidget {
  const DiaryVideoExportButton({
    super.key,
    required this.video,
    required this.controller,
  });
  final DiaryFileAttachment video;
  final DiaryVideoExportController controller;

  @override
  Widget build(BuildContext context) => DiaryVideoBusySwap(
    controller: controller,
    builder: (context) => IconButton(
      tooltip: context.l10n.videoExport,
      onPressed: controller.isBusy
          ? null
          : () => unawaited(
              runDiaryVideoExport(
                context,
                video: video,
                controller: controller,
              ),
            ),
      icon: const FaIcon(FontAwesomeIcons.download, size: 16),
    ),
  );
}

/// 44dp 见方的按钮位：导出进行中超过 300ms 时把 [builder] 画的按钮（导出
/// 按钮或视频菜单的 ⋮）换成等待指示，两者缩放淡入切换；导出较快时不闪。
/// 按钮随导出状态重建（忙碌时停用）。
class DiaryVideoBusySwap extends StatelessWidget {
  const DiaryVideoBusySwap({
    super.key,
    required this.controller,
    required this.builder,
  });

  final DiaryVideoExportController controller;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => SizedBox.square(
      dimension: 44,
      child: DelayedLoadingGate(
        loading: controller.isExporting,
        builder: (context, showLoading) => ExpressiveIconSwap(
          switchKey: showLoading,
          child: showLoading
              ? Center(
                  child: ExpressiveLoadingIndicator(
                    size: 24,
                    semanticLabel: context.l10n.videoExporting,
                  ),
                )
              : builder(context),
        ),
      ),
    ),
  );
}
