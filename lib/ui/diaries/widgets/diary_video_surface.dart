import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:video_player/video_player.dart';

class DiaryVideoSurface extends StatelessWidget {
  const DiaryVideoSurface({super.key, required this.controller});
  final DiaryVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    // 本地视频通常很快就绪：超过 300ms 才出现等待指示，避免每张视频卡闪一下。
    if (controller.isLoading) {
      return DelayedLoadingIndicator(semanticLabel: context.l10n.videoLoading);
    }
    final value = controller.player.value;
    final ratio = value.aspectRatio.isFinite && value.aspectRatio > 0
        ? value.aspectRatio
        : 16 / 9;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(controller.toggle()),
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: ratio,
              child: VideoPlayer(controller.player),
            ),
          ),
          // 暂停时的大播放按钮缩放淡入、开始播放时淡出，而不是硬切。
          ExpressiveIconSwap(
            switchKey: value.isPlaying,
            child: value.isPlaying
                ? const SizedBox.shrink()
                : Center(
                    child: IconButton.filledTonal(
                      tooltip: context.l10n.videoPlay,
                      onPressed: () => unawaited(controller.toggle()),
                      icon: const FaIcon(FontAwesomeIcons.play, size: 24),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
