import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_spacing.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_export_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_tile.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_controls.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_export_button.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_surface.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/desktop_page_arrows.dart';
import 'package:node_diary/ui/widgets/snack_bar_clearance.dart';
import 'package:node_diary/ui/widgets/swipe_dismiss_viewer.dart';
import 'package:video_player/video_player.dart';

/// 打开全屏播放页。
///
/// 与看图页同样的路由：不透明度为 false（下拉关闭时能看到下层页面）、整页
/// `standard` 淡入淡出，减少动画时直接切换。正文视频卡片传入自己的
/// [controller] 与 [exportController]（借用同一个原生播放器，返回时保留进度，
/// 卡片负责 `enterFullscreen` / `leaveFullscreen`）；视频小图没有播放器，
/// 不传时本页自己建一个、就绪后自动播放，关闭时释放（[playerFactory] 供测试
/// 注入）。
Future<void> openDiaryVideoFullscreen(
  BuildContext context, {
  required DiaryFileAttachment video,
  DiaryVideoPlayerController? controller,
  DiaryVideoExportController? exportController,
  VideoPlayerController Function(String source)? playerFactory,
  VideoExportService exportService = const VideoExportService(),
}) {
  // 编辑页的输入法不跟进全屏页：先收起，返回时插入点仍在原处。
  FocusManager.instance.primaryFocus?.unfocus();
  final duration = ExpressiveMotion.duration(
    context,
    ExpressiveMotion.standard,
  );
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      requestFocus: false,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, _, _) => DiaryVideoFullscreenPage(
        video: video,
        controller: controller,
        exportController: exportController,
        playerFactory: playerFactory,
        exportService: exportService,
      ),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation.drive(CurveTween(curve: ExpressiveMotion.effects)),
        child: child,
      ),
    ),
  );
}

/// 全屏播放页（#252 改版，原先的标题栏、文件名行与两行控件太杂）。
///
/// - 画面占满整页（安全区内），可捏合放大（[DiaryVideoSurface] 的 `zoomable`），
///   放大时锁住下拉关闭；未放大时下拉关闭，背景与上下栏随距离淡出，与看图页
///   一致。
/// - 上下栏叠在画面上：顶栏只有返回与导出（保存到相册 / 另存为），底栏是与
///   预览页共用的 [DiaryVideoPlaybackBar]（播放按钮 + 进度条 + 时间）。不再
///   显示文件名与“退出全屏”（返回即退出）。
/// - 沉浸：点按画面显示 / 隐藏上下栏与中央的播放 / 暂停按钮；播放中 3 秒没有
///   操作自动隐藏，按住底栏（拖进度、点播放）重新计时；暂停、播完或放不了时
///   一直显示。读屏等无障碍导航开启时不自动隐藏。
class DiaryVideoFullscreenPage extends StatefulWidget {
  const DiaryVideoFullscreenPage({
    super.key,
    required this.video,
    this.controller,
    this.exportController,
    this.playerFactory,
    this.exportService = const VideoExportService(),
  });
  final DiaryFileAttachment video;

  /// 借用的播放器（正文视频卡片）；为 null 时本页自建并在关闭时释放。
  final DiaryVideoPlayerController? controller;

  /// 借用的导出控制器；为 null 时本页自建并在关闭时释放。
  final DiaryVideoExportController? exportController;
  final VideoPlayerController Function(String source)? playerFactory;
  final VideoExportService exportService;

  @override
  State<DiaryVideoFullscreenPage> createState() =>
      _DiaryVideoFullscreenPageState();
}

class _DiaryVideoFullscreenPageState extends State<DiaryVideoFullscreenPage> {
  /// 播放中上下栏无操作多久后隐藏（非动画计时）。
  static const Duration _chromeIdle = Duration(seconds: 3);

  /// 叠在画面上的上下栏底色透明度：画面从栏后透出一点，文字仍清楚。
  static const double _barAlpha = 0.86;

  late final DiaryVideoPlayerController _player =
      widget.controller ??
      DiaryVideoPlayerController(
        source: widget.video.path,
        player: widget.playerFactory?.call(widget.video.path),
      );
  late final DiaryVideoExportController _export =
      widget.exportController ??
      DiaryVideoExportController(service: widget.exportService);

  bool _chromeShown = true;
  bool _zoomed = false;
  bool _wasPlaying = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _player.addListener(_handlePlayerChanged);
    _wasPlaying = _player.isPlaying;
    if (_wasPlaying) _scheduleHide();
    if (widget.controller == null) unawaited(_startOwnedPlayer());
  }

  /// 自建的播放器（从小图打开）：就绪后直接播放，点开小图就是为了看。
  Future<void> _startOwnedPlayer() async {
    await _player.initialize();
    if (!mounted || _player.hasFailed || _player.isPlaying) return;
    await _player.toggle();
  }

  /// 播放状态变化时调整上下栏：开始播放起计时隐藏，暂停 / 播完立即显示。
  void _handlePlayerChanged() {
    final playing = _player.isPlaying;
    if (playing == _wasPlaying) return;
    _wasPlaying = playing;
    if (playing) {
      _scheduleHide();
      return;
    }
    _hideTimer?.cancel();
    if (!_chromeShown && mounted) setState(() => _chromeShown = true);
  }

  /// 重新计时：时限到了仍在播放、上下栏仍显示时隐藏。页面销毁时取消。
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_chromeIdle, () {
      if (!mounted || !_player.isPlaying || !_chromeShown) return;
      if (MediaQuery.accessibleNavigationOf(context)) return;
      setState(() => _chromeShown = false);
    });
  }

  /// 点按画面：显示 / 隐藏上下栏。暂停时上下栏不收起（要拖进度、点播放）。
  void _toggleChrome() {
    final show = !_chromeShown || !_player.isPlaying;
    setState(() => _chromeShown = show);
    if (show && _player.isPlaying) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _handleZoomChanged(bool zoomed) {
    if (zoomed == _zoomed || !mounted) return;
    setState(() => _zoomed = zoomed);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _player.removeListener(_handlePlayerChanged);
    if (widget.controller == null) _player.dispose();
    if (widget.exportController == null) _export.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DesktopPageKeys(
    onEscape: () => Navigator.of(context).maybePop(),
    child: AnimatedBuilder(
      animation: _player,
      builder: (context, _) {
        final failed = _player.hasFailed;
        final chrome = _chromeShown || failed || !_player.isPlaying;
        final picture = SafeArea(
          child: failed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: DiaryAttachmentTile(
                      attachment: widget.video,
                      subtitle: context.l10n.videoPlaybackFailed,
                    ),
                  ),
                )
              : DiaryVideoSurface(
                  controller: _player,
                  zoomable: true,
                  onZoomChanged: _handleZoomChanged,
                  onTap: _toggleChrome,
                  showPauseButton: chrome,
                ),
        );
        return SwipeDismissViewer(
          enabled: !_zoomed,
          onDismiss: () => Navigator.of(context).pop(),
          child: picture,
          // 用透明 Scaffold 承载页面内提示条（导出成功/失败），并避让底部播放栏，
          // 与看图页（ImageViewerPage）的结构一致。
          builder: (context, swipeOpacity, content) => ColoredBox(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: swipeOpacity),
            child: SnackBarClearanceHost(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Stack(
                  children: <Widget>[
                    Positioned.fill(child: content),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _ChromeFade(
                        visible: chrome,
                        swipeOpacity: swipeOpacity,
                        child: _buildTopBar(context),
                      ),
                    ),
                    if (!failed)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SnackBarClearanceArea(
                          enabled: chrome,
                          child: _ChromeFade(
                            visible: chrome,
                            swipeOpacity: swipeOpacity,
                            child: _buildBottomBar(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  PreferredSizeWidget _buildTopBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppTopBar(
      backgroundColor: colors.surface.withValues(alpha: _barAlpha),
      foregroundColor: colors.onSurface,
      leading: IconButton(
        tooltip: context.l10n.commonBack,
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
      ),
      actions: <Widget>[
        DiaryVideoExportButton(video: widget.video, controller: _export),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface.withValues(alpha: _barAlpha),
      child: SafeArea(
        top: false,
        // 按住底栏（拖进度、点播放）重新计时，操作途中不会被收起。
        child: Listener(
          onPointerDown: (_) {
            if (_player.isPlaying) _scheduleHide();
          },
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s),
            child: DiaryVideoPlaybackBar(player: _player),
          ),
        ),
      ),
    );
  }
}

/// 上下栏的显示 / 隐藏：`fast` 淡入淡出，隐藏后不拦点按、读屏读不到；
/// [swipeOpacity] 是下拉关闭途中随距离变淡的那一层。
class _ChromeFade extends StatelessWidget {
  const _ChromeFade({
    required this.visible,
    required this.swipeOpacity,
    required this.child,
  });

  final bool visible;
  final double swipeOpacity;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: ExcludeSemantics(
      excluding: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        curve: ExpressiveMotion.effects,
        child: Opacity(opacity: swipeOpacity, child: child),
      ),
    ),
  );
}
