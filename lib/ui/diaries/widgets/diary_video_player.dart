import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/core/services/video_poster_cache.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_export_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/pages/diary_video_fullscreen_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_tile.dart';
import 'package:node_diary/ui/diaries/widgets/diary_media_viewport_gate.dart';
import 'package:node_diary/ui/diaries/widgets/diary_playback_interaction_guard.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_controls.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_embed_menu.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_surface.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_thumbnail.dart'
    show kDiaryVideoPosterMaxSide;
import 'package:video_player/video_player.dart';

/// 内嵌播放器持有播放/导出控制器，全屏页借用同一控制器和原生纹理。
/// 只有当前视图挂载 VideoPlayer，避免两处同时挂载同一原生播放器的画面。
///
/// 卡片是画面 + 一行控件（[DiaryVideoControls]）；[maxWidth] 为“调整大小”
/// 写入的宽度上限（拖动滑条时是预览值），正文列更窄时以列宽为准，高度随
/// 视频比例。[menu] 只在编辑页给出：控件行的导出按钮换成 ⋮ 菜单。
///
/// 未直接传入 [player] 时采用按需懒加载：挂载时只展示封面帧与播放按钮，
/// 不创建原生 `ExoPlayer` 与硬件 `MediaCodec`；点击播放后经全局单实例租约
/// 创建并播放，滑离视口、切到其他视频或路由被遮挡时自动释放原生播放器并
/// 退回封面态（记住比例、时长与断点位置）。
class DiaryVideoPlayer extends StatefulWidget {
  const DiaryVideoPlayer({
    super.key,
    required this.video,
    this.player,
    this.playerFactory,
    this.posters,
    this.exportService = const VideoExportService(),
    this.maxWidth,
    this.menu,
  });

  final DiaryFileAttachment video;

  /// 直接注入的底层播放器实例（主要供组件测试）：传入时沿用即时初始化。
  final VideoPlayerController? player;

  /// 懒加载激活时创建播放器的工厂；省略时由 [DiaryVideoPlayerController] 按路径创建。
  final VideoPlayerController Function(String source)? playerFactory;

  /// 懒加载封面帧与视频元信息缓存；省略时使用 [VideoPosterCache.shared]。
  final VideoPosterCache? posters;
  final VideoExportService exportService;
  final double? maxWidth;
  final DiaryVideoEmbedMenu? menu;

  @override
  State<DiaryVideoPlayer> createState() => _DiaryVideoPlayerState();
}

class _DiaryVideoPlayerState extends State<DiaryVideoPlayer> {
  DiaryVideoPlayerController? _controller;
  late DiaryVideoExportController _exportController;
  bool _activating = false;
  bool _lastFailed = false;
  bool _fullscreenOwned = false;
  bool _disposing = false;
  int _activationEpoch = 0;

  double? _rememberedAspectRatio;
  Duration _rememberedDuration = Duration.zero;
  Duration _resumePosition = Duration.zero;
  String? _posterPath;
  bool _posterRequested = false;

  bool get _isLazy => widget.player == null;
  VideoPosterCache get _posters => widget.posters ?? VideoPosterCache.shared;
  bool get _isFullscreen =>
      _fullscreenOwned || (_controller?.isFullscreen ?? false);

  @override
  void initState() {
    super.initState();
    _exportController = DiaryVideoExportController(
      service: widget.exportService,
    );
    _initForSource();
  }

  void _initForSource() {
    _resetPosterState();
    if (!_isLazy) {
      final controller = DiaryVideoPlayerController(
        source: widget.video.path,
        player: widget.player,
      );
      _controller = controller;
      unawaited(controller.initialize());
      return;
    }
    final cachedInfo = _posters.peekInfo(widget.video.path);
    if (cachedInfo != null) {
      _applyVideoInfo(
        cachedInfo.width,
        cachedInfo.height,
        cachedInfo.durationMs,
      );
    }
  }

  void _resetPosterState() {
    _lastFailed = false;
    _rememberedAspectRatio = null;
    _rememberedDuration = Duration.zero;
    _resumePosition = Duration.zero;
    _posterPath = null;
    _posterRequested = false;
  }

  void _applyVideoInfo(int width, int height, int durationMs) {
    if (_rememberedAspectRatio == null && width > 0 && height > 0) {
      _rememberedAspectRatio = width / height;
    }
    if (_rememberedDuration == Duration.zero && durationMs > 0) {
      _rememberedDuration = Duration(milliseconds: durationMs);
    }
  }

  @override
  void didUpdateWidget(DiaryVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exportService != widget.exportService) {
      _exportController.dispose();
      _exportController = DiaryVideoExportController(
        service: widget.exportService,
      );
    }
    if (oldWidget.video.path != widget.video.path ||
        oldWidget.player != widget.player ||
        oldWidget.posters != widget.posters) {
      if (oldWidget.player == null) {
        unawaited(_deactivate(force: true));
      } else {
        _controller?.dispose();
        _controller = null;
      }
      _initForSource();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLazy) {
      final controller = _controller;
      // 全屏路由会遮住编辑器，但仍使用本控制器；只有其他路由覆盖才暂停。
      if (controller != null &&
          !TickerMode.valuesOf(context).enabled &&
          !controller.isFullscreen) {
        unawaited(controller.pause());
      }
    }
  }

  void _handleViewportActive(bool active) {
    if (!_isLazy || _disposing) return;
    if (active) {
      _loadPosterAndInfo();
    } else {
      unawaited(_deactivate());
    }
  }

  void _loadPosterAndInfo() {
    if (_posterRequested || !_posters.isSupported) return;
    _posterRequested = true;
    final source = widget.video.path;
    final posters = _posters;
    unawaited(
      posters.posterOf(source, maxSide: kDiaryVideoPosterMaxSide).then((path) {
        if (!mounted ||
            _disposing ||
            source != widget.video.path ||
            path == null) {
          return;
        }
        setState(() => _posterPath = path);
      }),
    );
    unawaited(
      posters.infoOf(source).then((info) {
        if (!mounted ||
            _disposing ||
            source != widget.video.path ||
            info == null) {
          return;
        }
        final beforeRatio = _rememberedAspectRatio;
        final beforeDuration = _rememberedDuration;
        _applyVideoInfo(info.width, info.height, info.durationMs);
        if (_rememberedAspectRatio != beforeRatio ||
            _rememberedDuration != beforeDuration) {
          setState(() {});
        }
      }),
    );
  }

  Future<void> _activateAndPlay() async {
    if (!_isLazy || _activating || _disposing) return;
    final existing = _controller;
    if (existing != null) {
      await existing.toggle();
      return;
    }
    final epoch = ++_activationEpoch;
    final source = widget.video.path;
    setState(() {
      _activating = true;
      _lastFailed = false;
    });
    try {
      await DiaryVideoPlayerController.acquireInlineLease(_releaseLocal);
      if (!mounted ||
          _disposing ||
          epoch != _activationEpoch ||
          source != widget.video.path) {
        return;
      }
      final controller = DiaryVideoPlayerController(
        source: source,
        player: widget.playerFactory?.call(source),
      );
      setState(() => _controller = controller);
      await controller.initialize();
      if (!mounted ||
          _disposing ||
          epoch != _activationEpoch ||
          !identical(_controller, controller)) {
        unawaited(controller.disposeAsync());
        return;
      }
      if (controller.hasFailed) {
        DiaryVideoPlayerController.detachInlineLease(_releaseLocal);
        _controller = null;
        setState(() {
          _lastFailed = true;
          _activating = false;
        });
        unawaited(controller.disposeAsync());
        return;
      }
      final value = controller.player.value;
      if (value.aspectRatio.isFinite && value.aspectRatio > 0) {
        _rememberedAspectRatio = value.aspectRatio;
      }
      if (value.duration > Duration.zero) {
        _rememberedDuration = value.duration;
      }
      if (_resumePosition > Duration.zero && _resumePosition < value.duration) {
        await controller.seek(_resumePosition);
      }
      if (!mounted ||
          _disposing ||
          epoch != _activationEpoch ||
          !identical(_controller, controller)) {
        return;
      }
      await controller.toggle();
    } finally {
      if (mounted && !_disposing && epoch == _activationEpoch) {
        setState(() => _activating = false);
      }
    }
  }

  Future<void> _deactivate({bool force = false}) async {
    final controller = _controller;
    if (!force && controller != null && controller.isFullscreen) {
      return;
    }
    DiaryVideoPlayerController.detachInlineLease(_releaseLocal);
    await _releaseLocal(force: force);
  }

  Future<void> _releaseLocal({bool force = false}) async {
    final controller = _controller;
    if (!force && controller != null && controller.isFullscreen) {
      return;
    }
    _activationEpoch++;
    _activating = false;
    if (controller == null) return;
    final value = controller.player.value;
    if (value.isInitialized) {
      if (value.aspectRatio.isFinite && value.aspectRatio > 0) {
        _rememberedAspectRatio = value.aspectRatio;
      }
      if (value.duration > Duration.zero) {
        _rememberedDuration = value.duration;
      }
      _resumePosition = value.position >= value.duration
          ? Duration.zero
          : value.position;
    }
    _controller = null;
    if (mounted && !_disposing) setState(() {});
    await controller.disposeAsync();
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller != null) {
      if (!controller.enterFullscreen()) return;
      try {
        await openDiaryVideoFullscreen(
          context,
          video: widget.video,
          controller: controller,
          exportController: _exportController,
        );
      } finally {
        controller.leaveFullscreen();
      }
      return;
    }
    if (_activating || _lastFailed || _fullscreenOwned) return;
    await DiaryVideoPlayerController.releaseInlineLease();
    if (!mounted || _disposing) return;
    setState(() => _fullscreenOwned = true);
    try {
      await openDiaryVideoFullscreen(
        context,
        video: widget.video,
        exportController: _exportController,
        playerFactory: widget.playerFactory,
        exportService: widget.exportService,
      );
    } finally {
      if (mounted && !_disposing) {
        setState(() => _fullscreenOwned = false);
      }
    }
  }

  @override
  void dispose() {
    _disposing = true;
    if (_isLazy) {
      DiaryVideoPlayerController.detachInlineLease(_releaseLocal);
    }
    _controller?.dispose();
    _controller = null;
    _exportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLazy) {
      return _buildCard(context, viewportActive: true);
    }
    return DiaryMediaViewportGate(
      suspendWhenTickerDisabled: !_isFullscreen,
      onActiveChanged: _handleViewportActive,
      builder: (context, active) => _buildCard(context, viewportActive: active),
    );
  }

  Widget _buildCard(BuildContext context, {required bool viewportActive}) {
    final controller = _controller;
    if (controller == null) {
      return DiaryPlaybackInteractionGuard(
        child: _buildCardBody(
          context,
          controller: null,
          viewportActive: viewportActive,
        ),
      );
    }
    return DiaryPlaybackInteractionGuard(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _buildCardBody(
          context,
          controller: controller,
          viewportActive: viewportActive,
        ),
      ),
    );
  }

  Widget _buildCardBody(
    BuildContext context, {
    required DiaryVideoPlayerController? controller,
    required bool viewportActive,
  }) {
    final colors = Theme.of(context).colorScheme;
    final value = controller?.player.value;
    // VideoPlayerValue.aspectRatio 在初始化前返回 1.0，必须先看 isInitialized：
    // 否则卡片先是正方形，初始化后再跳成真实比例，下方正文整体位移。
    final double ratio;
    if (value != null &&
        value.isInitialized &&
        value.aspectRatio.isFinite &&
        value.aspectRatio > 0) {
      ratio = value.aspectRatio;
    } else {
      ratio = _rememberedAspectRatio ?? (16 / 9);
    }
    final failed = controller?.hasFailed ?? _lastFailed;
    final canFullscreen = controller == null
        ? !_activating && !failed && !_fullscreenOwned
        : !controller.isLoading && !failed && !controller.isFullscreen;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth ?? double.infinity,
        ),
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (failed)
                DiaryAttachmentTile(
                  attachment: widget.video,
                  icon: FontAwesomeIcons.fileVideo,
                  subtitle: context.l10n.videoPlaybackFailed,
                )
              else
                // 16:9 占位到真实比例（如竖屏视频）的高度变化平滑过渡。
                AnimatedSize(
                  duration: ExpressiveMotion.durationNonZero(
                    context,
                    ExpressiveMotion.medium,
                  ),
                  curve: ExpressiveMotion.effects,
                  alignment: Alignment.topCenter,
                  child: AspectRatio(
                    aspectRatio: ratio.clamp(0.6, 3).toDouble(),
                    child: controller == null
                        ? DiaryVideoIdleSurface(
                            posterPath: viewportActive ? _posterPath : null,
                            onPlay: _activating
                                ? null
                                : () => unawaited(_activateAndPlay()),
                          )
                        : controller.isFullscreen
                        ? const SizedBox.expand()
                        : DiaryVideoSurface(controller: controller),
                  ),
                ),
              DiaryVideoControls(
                video: widget.video,
                controller: controller,
                exportController: _exportController,
                menu: widget.menu,
                onIdlePlay: failed || _activating
                    ? null
                    : () => unawaited(_activateAndPlay()),
                idlePosition: _resumePosition,
                idleDuration: _rememberedDuration,
                onFullscreen: canFullscreen
                    ? () => unawaited(_openFullscreen())
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
