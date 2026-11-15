import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:node_diary/ui/widgets/double_tap_zoom_viewer.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:video_player/video_player.dart';

/// 视频画面：按视频比例 contain 居中，点按画面播放 / 暂停，暂停时中央有大
/// 播放按钮。
///
/// [zoomable] 为 true 时（全屏页、“这天的照片”预览、存储管理预览）画面可
/// 双指捏合放大、放大后单指平移，与看图页同一个 [DoubleTapZoomViewer]（#252）；
/// 未放大时不响应双击，单击立即播放 / 暂停，放大后双击复原（此时单击要等
/// 双击判定）。播放按钮叠在缩放层之上，不随画面放大。[onZoomChanged] 报告
/// 放大态，宿主据此锁住翻页与下拉关闭。正文里的视频卡片不开启：它在滚动
/// 的正文里，捏合会与页面滚动冲突，要放大先进全屏。
///
/// [onTap] 取代“点按画面播放 / 暂停”（全屏页用来显示 / 隐藏上下栏），此时
/// 播放 / 暂停只经中央的按钮；[showPauseButton] 为 true 时播放中也显示
/// 中央按钮（换成暂停），全屏页随上下栏一起出现与隐藏。
class DiaryVideoSurface extends StatelessWidget {
  const DiaryVideoSurface({
    super.key,
    required this.controller,
    this.zoomable = false,
    this.onZoomChanged,
    this.onTap,
    this.showPauseButton = false,
  });
  final DiaryVideoPlayerController controller;
  final bool zoomable;
  final ValueChanged<bool>? onZoomChanged;
  final VoidCallback? onTap;
  final bool showPauseButton;

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
    final picture = Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: VideoPlayer(controller.player),
      ),
    );
    final playing = value.isPlaying;
    final showButton = !playing || showPauseButton;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => unawaited(controller.toggle()),
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          if (zoomable)
            DoubleTapZoomViewer(
              doubleTapZoomsIn: false,
              onZoomChanged: onZoomChanged,
              child: picture,
            )
          else
            picture,
          // 暂停时的大播放按钮缩放淡入、开始播放时淡出，而不是硬切；全屏页
          // 显示上下栏时播放中换成暂停按钮。
          ExpressiveIconSwap(
            switchKey: showButton ? playing : 'hidden',
            child: showButton
                ? Center(
                    child: IconButton.filledTonal(
                      tooltip: playing
                          ? context.l10n.videoPause
                          : context.l10n.videoPlay,
                      onPressed: () => unawaited(controller.toggle()),
                      icon: FaIcon(
                        playing
                            ? FontAwesomeIcons.pause
                            : FontAwesomeIcons.play,
                        size: 24,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
