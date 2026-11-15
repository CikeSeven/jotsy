import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_spacing.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_export_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_embed_menu.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_export_button.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/width_layout_builder.dart';

/// 正文视频卡片画面下方的一行控件（#252 精简）：播放 / 暂停、进度条与时间、
/// 导出（只读正文）或 ⋮ 菜单（编辑页，[menu]）、全屏。不再显示文件名。
///
/// 卡片调窄后（“调整大小”，最窄 `kDiaryVideoMinWidth`）时间文字放不下，
/// 宽度不足 [timeMinWidth] 时只留进度条；按钮始终在。
class DiaryVideoControls extends StatelessWidget {
  const DiaryVideoControls({
    super.key,
    required this.video,
    required this.controller,
    required this.exportController,
    required this.onFullscreen,
    this.menu,
  });

  final DiaryFileAttachment video;
  final DiaryVideoPlayerController controller;
  final DiaryVideoExportController exportController;
  final VoidCallback? onFullscreen;
  final DiaryVideoEmbedMenu? menu;

  /// 控件行宽于此才显示时间文字。
  static const double timeMinWidth = 300;

  @override
  Widget build(BuildContext context) {
    final value = controller.player.value;
    final ready = !controller.isLoading && !controller.hasFailed;
    final menu = this.menu;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
      child: WidthLayoutBuilder(
        builder: (context, width) => Row(
          children: [
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                tooltip: value.isPlaying
                    ? context.l10n.videoPause
                    : context.l10n.videoPlay,
                onPressed: ready ? () => unawaited(controller.toggle()) : null,
                icon: ExpressiveIconSwap(
                  switchKey: value.isPlaying,
                  child: FaIcon(
                    value.isPlaying
                        ? FontAwesomeIcons.pause
                        : FontAwesomeIcons.play,
                    size: 16,
                  ),
                ),
              ),
            ),
            Expanded(
              child: DiaryVideoProgressBar(
                controller: controller,
                enabled: ready,
                showTime: width >= timeMinWidth,
              ),
            ),
            if (menu != null)
              DiaryVideoMenuButton(
                video: video,
                menu: menu,
                exportController: exportController,
              )
            else
              DiaryVideoExportButton(
                video: video,
                controller: exportController,
              ),
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                tooltip: context.l10n.videoFullscreen,
                onPressed: onFullscreen,
                icon: const FaIcon(FontAwesomeIcons.expand, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 视频进度条 + 时间文字（正文播放器与“这天的照片”预览页共用）。
///
/// 拖动期间只更新本地值（滑块与时间文字跟手），松手时才 seek 一次：若在
/// onChanged 中逐帧 seek，原生播放器会收到成串请求，滑块还会被尚未完成的
/// 播放位置拉回。seek 完成前保留拖动值，避免松手瞬间回跳。
class DiaryVideoProgressBar extends StatefulWidget {
  const DiaryVideoProgressBar({
    super.key,
    required this.controller,
    required this.enabled,
    this.showTime = true,
  });

  final DiaryVideoPlayerController controller;
  final bool enabled;

  /// 显示“已播 / 总长”文字；窄卡片放不下时只留进度条。
  final bool showTime;

  @override
  State<DiaryVideoProgressBar> createState() => _DiaryVideoProgressBarState();
}

class _DiaryVideoProgressBarState extends State<DiaryVideoProgressBar> {
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
        if (widget.showTime)
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

/// 视频下方的播放 / 暂停按钮与进度条（全屏播放页、“这天的照片”预览页与
/// 存储管理的视频预览页共用）；播放器未就绪或失败时整行停用，还没有播放器（读取地址中、
/// 读不到）时留出同样的高度，进度条出现时页面不跳。
class DiaryVideoPlaybackBar extends StatelessWidget {
  const DiaryVideoPlaybackBar({super.key, required this.player});

  final DiaryVideoPlayerController? player;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    final l10n = context.l10n;
    final ready = player != null && !player.isLoading && !player.hasFailed;
    final playing = player?.isPlaying ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s,
        0,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 44,
            child: IconButton(
              tooltip: playing ? l10n.videoPause : l10n.videoPlay,
              onPressed: ready ? () => unawaited(player.toggle()) : null,
              icon: ExpressiveIconSwap(
                switchKey: playing,
                child: FaIcon(
                  playing ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                  size: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: player == null
                // 还没有播放器（读取地址中、读不到）：留出同样的高度，进度条
                // 出现时页面不跳。
                ? const SizedBox(height: 48)
                : DiaryVideoProgressBar(controller: player, enabled: ready),
          ),
        ],
      ),
    );
  }
}
