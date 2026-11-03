import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../widgets/double_tap_zoom_viewer.dart';
import '../../../widgets/expressive_icon_swap.dart';
import '../../../widgets/expressive_image_frame.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../controllers/diary_video_player_controller.dart';
import '../diary_video_controls.dart';
import '../diary_video_surface.dart';

// “这天的照片”预览页的单页：图片（双击 / 捏合缩放）与视频（封面帧 + 播放）。
// 翻页、勾选与插入在 DiaryDayPhotoPreviewPage。

/// 预览页的一张图片：整张 contain 居中，双击 / 捏合缩放（[DoubleTapZoomViewer]）。
///
/// 初始页带共享元素 [hero] 时沿用看图页的做法（[ImageViewerHeroTarget]）：
/// 原图比例的盒子里先显示缩略图画面，大图解码后淡入覆盖；放大后关闭 Hero，
/// 返回只淡出。宿主据 [onZoomChanged] 在放大时锁住翻页与下拉关闭。
class DiaryDayPhotoPreviewImage extends StatefulWidget {
  const DiaryDayPhotoPreviewImage({
    super.key,
    required this.image,
    required this.onZoomChanged,
    this.hero,
  });

  final ImageProvider image;
  final ValueChanged<bool> onZoomChanged;
  final ImageViewerHero? hero;

  @override
  State<DiaryDayPhotoPreviewImage> createState() =>
      _DiaryDayPhotoPreviewImageState();
}

class _DiaryDayPhotoPreviewImageState extends State<DiaryDayPhotoPreviewImage> {
  bool _zoomed = false;

  void _handleZoomChanged(bool zoomed) {
    if (mounted && zoomed != _zoomed) setState(() => _zoomed = zoomed);
    widget.onZoomChanged(zoomed);
  }

  Widget _image(BoxFit fit) => Image(
    image: widget.image,
    fit: fit,
    frameBuilder: expressiveImageFrameBuilder,
    // 有共享元素时缩略图画面垫在下面，读不出大图也保持它，不再叠失败图标。
    errorBuilder: (BuildContext context, _, _) => widget.hero != null
        ? const SizedBox.shrink()
        : _PreviewUnavailable(
            icon: FontAwesomeIcons.image,
            message: context.l10n.diaryDayPhotosPreviewFailed,
          ),
  );

  @override
  Widget build(BuildContext context) {
    final hero = widget.hero;
    return DoubleTapZoomViewer(
      onZoomChanged: _handleZoomChanged,
      child: hero == null
          ? Center(child: _image(BoxFit.contain))
          : HeroMode(
              enabled: !_zoomed,
              child: ImageViewerHeroTarget(
                hero: hero,
                fullImage: _image(BoxFit.cover),
              ),
            ),
    );
  }
}

/// 预览页的一段视频：封面帧垫底，播放器就绪后叠上画面；下方一行播放 /
/// 暂停与进度（[DiaryVideoProgressBar]，与正文播放器同一套）。
///
/// 时序：挂载后经 [loadSource] 取播放地址（相册原文件，不复制），取到才建
/// [DiaryVideoPlayerController] 并初始化；不自动播放。页面翻走时 PageView
/// 卸载本页，播放器随之释放；翻页时宿主另行暂停正在播放的视频
/// （[DiaryVideoPlayerController.pauseActive]）。取不到地址或初始化失败时
/// 封面帧上显示“无法播放”。
class DiaryDayPhotoPreviewVideo extends StatefulWidget {
  const DiaryDayPhotoPreviewVideo({
    super.key,
    required this.poster,
    required this.aspectRatio,
    required this.loadSource,
  });

  final ImageProvider poster;

  /// 视频画面的宽高比（相册记录的尺寸）；未知时为 null，封面帧按自身比例。
  final double? aspectRatio;
  final Future<String?> Function() loadSource;

  @override
  State<DiaryDayPhotoPreviewVideo> createState() =>
      _DiaryDayPhotoPreviewVideoState();
}

class _DiaryDayPhotoPreviewVideoState extends State<DiaryDayPhotoPreviewVideo> {
  DiaryVideoPlayerController? _player;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    String? source;
    try {
      source = await widget.loadSource();
    } catch (error) {
      debugPrint('Day photo video source failed: $error');
    }
    if (!mounted) return;
    if (source == null) {
      setState(() => _unavailable = true);
      return;
    }
    final player = DiaryVideoPlayerController(source: source);
    setState(() => _player = player);
    unawaited(player.initialize());
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null) return _buildFrame(context, null);
    return AnimatedBuilder(
      animation: player,
      builder: (BuildContext context, _) => _buildFrame(context, player),
    );
  }

  Widget _buildFrame(BuildContext context, DiaryVideoPlayerController? player) {
    final failed = _unavailable || (player?.hasFailed ?? false);
    final ratio = widget.aspectRatio;
    final poster = Image(
      image: widget.poster,
      fit: BoxFit.contain,
      frameBuilder: expressiveImageFrameBuilder,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Center(
                child: ratio == null
                    ? poster
                    : AspectRatio(aspectRatio: ratio, child: poster),
              ),
              // 读取中由 DiaryVideoSurface 自己显示延迟出现的等待指示，封面帧
              // 留在下面；就绪后画面盖住封面帧，点按播放 / 暂停。
              if (player != null && !failed)
                DiaryVideoSurface(controller: player),
              if (failed)
                _PreviewUnavailable(
                  icon: FontAwesomeIcons.film,
                  message: context.l10n.videoPlaybackFailed,
                ),
            ],
          ),
        ),
        _VideoControls(player: failed ? null : player),
      ],
    );
  }
}

/// 视频下方的播放 / 暂停与进度条；播放器未就绪或失败时整行停用。
class _VideoControls extends StatelessWidget {
  const _VideoControls({required this.player});

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

/// 读不出图片或放不了视频：居中的图标 + 一行说明。
class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable({required this.icon, required this.message});

  final FaIconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FaIcon(icon, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.s),
              Flexible(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
