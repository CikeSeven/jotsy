import 'package:flutter/material.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_export_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_tile.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_controls.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_surface.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

/// 全屏页只装配共享播放器，不重新初始化/释放原生播放器，返回时保留进度。
class DiaryVideoFullscreenPage extends StatelessWidget {
  const DiaryVideoFullscreenPage({
    super.key,
    required this.video,
    required this.controller,
    required this.exportController,
  });
  final DiaryFileAttachment video;
  final DiaryVideoPlayerController controller;
  final DiaryVideoExportController exportController;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppTopBar(title: Text(context.l10n.videoFullscreen)),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: controller.hasFailed
                  ? Center(
                      child: DiaryAttachmentTile(
                        attachment: video,
                        subtitle: context.l10n.videoPlaybackFailed,
                      ),
                    )
                  : DiaryVideoSurface(controller: controller),
            ),
            DiaryVideoControls(
              video: video,
              controller: controller,
              exportController: exportController,
              fullscreen: true,
              onFullscreen: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    ),
  );
}
