import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_export_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/pages/diary_video_fullscreen_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_tile.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_controls.dart';
import 'package:node_diary/ui/diaries/widgets/diary_playback_interaction_guard.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_surface.dart';
import 'package:video_player/video_player.dart';

/// 内嵌播放器持有播放/导出控制器，全屏页借用同一控制器和原生纹理。
/// 只有当前视图挂载 VideoPlayer，避免两处同时挂载同一原生播放器的画面。
class DiaryVideoPlayer extends StatefulWidget {
  const DiaryVideoPlayer({
    super.key,
    required this.video,
    this.player,
    this.exportService = const VideoExportService(),
  });

  final DiaryFileAttachment video;
  final VideoPlayerController? player;
  final VideoExportService exportService;

  @override
  State<DiaryVideoPlayer> createState() => _DiaryVideoPlayerState();
}

class _DiaryVideoPlayerState extends State<DiaryVideoPlayer> {
  late DiaryVideoPlayerController _controller;
  late DiaryVideoExportController _exportController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _controller = DiaryVideoPlayerController(
      source: widget.video.path,
      player: widget.player,
    );
    _exportController = DiaryVideoExportController(
      service: widget.exportService,
    );
    unawaited(_controller.initialize());
  }

  @override
  void didUpdateWidget(DiaryVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.path != widget.video.path ||
        oldWidget.player != widget.player) {
      _controller.dispose();
      _exportController.dispose();
      _initializeControllers();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 全屏路由会遮住编辑器，但仍使用本控制器；只有其他路由覆盖才暂停。
    if (!TickerMode.valuesOf(context).enabled && !_controller.isFullscreen) {
      unawaited(_controller.pause());
    }
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (!controller.enterFullscreen()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          requestFocus: false,
          transitionDuration: ExpressiveMotion.duration(context),
          reverseTransitionDuration: ExpressiveMotion.duration(
            context,
            ExpressiveMotion.fast,
          ),
          pageBuilder: (context, _, _) => DiaryVideoFullscreenPage(
            video: widget.video,
            controller: controller,
            exportController: _exportController,
          ),
          transitionsBuilder: (context, animation, _, child) => FadeTransition(
            opacity: animation.drive(
              CurveTween(curve: ExpressiveMotion.effects),
            ),
            child: child,
          ),
        ),
      );
    } finally {
      controller.leaveFullscreen();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _exportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DiaryPlaybackInteractionGuard(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final colors = Theme.of(context).colorScheme;
        final value = _controller.player.value;
        final ratio = value.aspectRatio.isFinite && value.aspectRatio > 0
            ? value.aspectRatio
            : 16 / 9;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.hasFailed)
                  DiaryAttachmentTile(
                    attachment: widget.video,
                    icon: FontAwesomeIcons.fileVideo,
                    subtitle: context.l10n.videoPlaybackFailed,
                  )
                else
                  AspectRatio(
                    aspectRatio: ratio.clamp(0.6, 3).toDouble(),
                    child: _controller.isFullscreen
                        ? const SizedBox.expand()
                        : DiaryVideoSurface(controller: _controller),
                  ),
                DiaryVideoControls(
                  video: widget.video,
                  controller: _controller,
                  exportController: _exportController,
                  onFullscreen:
                      _controller.isLoading ||
                          _controller.hasFailed ||
                          _controller.isFullscreen
                      ? null
                      : () => unawaited(_openFullscreen()),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
