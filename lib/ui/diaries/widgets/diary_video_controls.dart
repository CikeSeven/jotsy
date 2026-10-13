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
                child: _VideoProgressBar(
                  controller: controller,
                  enabled: !controller.isLoading && !controller.hasFailed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 视频进度条 + 时间文字。
///
/// 拖动期间只更新本地值（滑块与时间文字跟手），松手时才 seek 一次：若在
/// onChanged 中逐帧 seek，原生播放器会收到成串请求，滑块还会被尚未完成的
/// 播放位置拉回。seek 完成前保留拖动值，避免松手瞬间回跳。
class _VideoProgressBar extends StatefulWidget {
  const _VideoProgressBar({required this.controller, required this.enabled});

  final DiaryVideoPlayerController controller;
  final bool enabled;

  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<_VideoProgressBar> {
  double? _dragMilliseconds;

  Future<void> _commitSeek(double milliseconds) async {
    setState(() => _dragMilliseconds = milliseconds);
    await widget.controller.seek(Duration(milliseconds: milliseconds.round()));
    if (mounted && _dragMilliseconds == milliseconds) {
      setState(() => _dragMilliseconds = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = widget.controller.player.value;
    final durationMs = value.duration.inMilliseconds;
    final positionMs =
        _dragMilliseconds ??
        value.position.inMilliseconds.clamp(0, durationMs).toDouble();
    final displayedPosition = Duration(milliseconds: positionMs.round());
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: context.l10n.videoProgress,
            child: Slider(
              min: 0,
              max: durationMs <= 0 ? 1 : durationMs.toDouble(),
              value: positionMs
                  .clamp(0, durationMs <= 0 ? 1 : durationMs)
                  .toDouble(),
              onChanged: widget.enabled
                  ? (position) => setState(() => _dragMilliseconds = position)
                  : null,
              onChangeEnd: widget.enabled
                  ? (position) => unawaited(_commitSeek(position))
                  : null,
            ),
          ),
        ),
        Text(
          '${formatRecordingDuration(displayedPosition)} / ${formatRecordingDuration(value.duration)}',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
