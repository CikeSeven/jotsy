import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_export_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_export_button.dart';

/// 内嵌/全屏共享控件，窄屏把命令和进度分为两行，避免挤占播放进度。
class DiaryVideoControls extends StatelessWidget {
  const DiaryVideoControls({
    super.key,
    required this.video,
    required this.controller,
    required this.exportController,
    required this.onFullscreen,
    this.fullscreen = false,
  });

  final DiaryFileAttachment video;
  final DiaryVideoPlayerController controller;
  final DiaryVideoExportController exportController;
  final VoidCallback? onFullscreen;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = controller.player.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  video.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: colors.onSurface),
                ),
              ),
              DiaryVideoExportButton(
                video: video,
                controller: exportController,
              ),
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  tooltip: fullscreen
                      ? context.l10n.videoExitFullscreen
                      : context.l10n.videoFullscreen,
                  onPressed: onFullscreen,
                  icon: FaIcon(
                    fullscreen
                        ? FontAwesomeIcons.compress
                        : FontAwesomeIcons.expand,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  tooltip: value.isPlaying
                      ? context.l10n.videoPause
                      : context.l10n.videoPlay,
                  onPressed: controller.isLoading || controller.hasFailed
                      ? null
                      : () => unawaited(controller.toggle()),
                  icon: FaIcon(
                    value.isPlaying
                        ? FontAwesomeIcons.pause
                        : FontAwesomeIcons.play,
                    size: 16,
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  label: context.l10n.videoProgress,
                  child: Slider(
                    min: 0,
                    max: value.duration.inMilliseconds <= 0
                        ? 1
                        : value.duration.inMilliseconds.toDouble(),
                    value: value.position.inMilliseconds
                        .clamp(0, value.duration.inMilliseconds)
                        .toDouble(),
                    onChanged: controller.isLoading || controller.hasFailed
                        ? null
                        : (position) => unawaited(
                            controller.seek(
                              Duration(milliseconds: position.round()),
                            ),
                          ),
                  ),
                ),
              ),
              Text(
                '${formatRecordingDuration(value.position)} / ${formatRecordingDuration(value.duration)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
