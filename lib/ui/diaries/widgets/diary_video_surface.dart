import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:video_player/video_player.dart';

class DiaryVideoSurface extends StatelessWidget {
  const DiaryVideoSurface({super.key, required this.controller});
  final DiaryVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return Center(
        child: ExpressiveLoadingIndicator(
          semanticLabel: context.l10n.videoLoading,
        ),
      );
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
          if (!value.isPlaying)
            Center(
              child: IconButton.filledTonal(
                tooltip: context.l10n.videoPlay,
                onPressed: () => unawaited(controller.toggle()),
                icon: const FaIcon(FontAwesomeIcons.play, size: 24),
              ),
            ),
        ],
      ),
    );
  }
}
