import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 拥有一个正文视频的异步初始化/播放状态，并在后台、退出和切换视频时暂停。
/// 不自动播放；销毁后的原生回调不能再通知已经离开的编辑器或预览页。
///
/// 同时维护全局正文内嵌视频卡片的单实例租约（[acquireInlineLease] /
/// [releaseInlineLease]）：同一时刻至多只有一个懒加载的正文视频持有原生
/// 播放器与硬件解码器，且新建下一个播放器前会等待上一个原生 `dispose()`
/// 完成，避免多段视频耗尽 Android `MediaCodec` 槽位与图形内存。
class DiaryVideoPlayerController extends ChangeNotifier
    with WidgetsBindingObserver {
  DiaryVideoPlayerController({
    required String source,
    VideoPlayerController? player,
  }) : player = player ?? _createPlayer(source) {
    this.player.addListener(_onPlayerChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  final VideoPlayerController player;
  static DiaryVideoPlayerController? _active;
  static Future<void> Function()? _inlineLeaseOwner;
  static Future<void>? _pendingRelease;
  Future<void>? _initialization;
  Future<void>? _disposal;
  bool _disposed = false;
  bool _trackReleaseOnDispose = false;
  bool _loading = true;
  bool _failed = false;
  bool _changingPlayback = false;
  bool _fullscreen = false;

  bool get isLoading => _loading;
  bool get hasFailed => _failed || player.value.hasError;
  bool get isPlaying => player.value.isPlaying;
  bool get isFullscreen => _fullscreen;

  bool enterFullscreen() {
    if (_disposed || _loading || hasFailed || _fullscreen) return false;
    _fullscreen = true;
    notifyListeners();
    return true;
  }

  void leaveFullscreen() {
    if (_disposed) return;
    _fullscreen = false;
    notifyListeners();
  }

  static Future<void> pauseActive() async => _active?.pause();

  /// 申请成为全局唯一活跃的正文视频卡片：先释放上一位持有者并等待其底层
  /// 原生播放器释放完毕，再允许调用方初始化新的原生解码器。
  static Future<void> acquireInlineLease(
    Future<void> Function() release,
  ) async {
    final previous = _inlineLeaseOwner;
    _inlineLeaseOwner = release;
    if (previous != null && !identical(previous, release)) {
      await previous();
    }
    await _pendingRelease;
  }

  /// 主动释放当前活跃的正文视频卡片（如从小图或封面直接进入全屏播放前）。
  static Future<void> releaseInlineLease([
    Future<void> Function()? owner,
  ]) async {
    if (owner != null && !identical(_inlineLeaseOwner, owner)) {
      return;
    }
    final current = _inlineLeaseOwner;
    _inlineLeaseOwner = null;
    if (current != null) {
      await current();
    }
    await _pendingRelease;
  }

  /// 仅摘除租约登记而不再次回调释放函数（供持有者自行释放或卸载时调用）。
  static void detachInlineLease(Future<void> Function() owner) {
    if (identical(_inlineLeaseOwner, owner)) {
      _inlineLeaseOwner = null;
    }
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      await player.initialize();
    } catch (_) {
      _failed = true;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggle() async {
    if (_disposed || _loading || hasFailed || _changingPlayback) return;
    _changingPlayback = true;
    try {
      if (player.value.isPlaying) {
        await pause();
      } else {
        if (_active != null && _active != this) await _active!.pause();
        if (_disposed) return;
        if (player.value.position >= player.value.duration) {
          await player.seekTo(Duration.zero);
        }
        if (_disposed) return;
        _active = this;
        await player.play();
      }
    } catch (_) {
      _fail();
    } finally {
      _changingPlayback = false;
    }
  }

  Future<void> pause() async {
    if (_disposed || !player.value.isInitialized) return;
    try {
      await player.pause();
      if (_active == this) _active = null;
    } catch (_) {
      _fail();
    }
  }

  Future<void> seek(Duration position) async {
    if (_disposed || _loading || hasFailed) return;
    try {
      await player.seekTo(
        Duration(
          milliseconds: position.inMilliseconds.clamp(
            0,
            player.value.duration.inMilliseconds,
          ),
        ),
      );
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    if (_disposed) return;
    _failed = true;
    notifyListeners();
  }

  void _onPlayerChanged() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(pause());
  }

  /// 释放控制器并等待底层原生 `VideoPlayerController.dispose()` 完成。
  /// [trackPendingRelease] 为 true 时纳入全局租约等待，确保紧接着激活的
  /// 下一段视频等待旧硬件解码器归还；组件同步 `dispose()` 卸载时为 false，
  /// 避免在已结束的异步区域残留未消费的微任务。
  Future<void> disposeAsync({bool trackPendingRelease = true}) {
    if (_disposed) return _disposal ?? Future<void>.value();
    _trackReleaseOnDispose = trackPendingRelease;
    dispose();
    return _disposal ?? Future<void>.value();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final trackPendingRelease = _trackReleaseOnDispose;
    _trackReleaseOnDispose = false;
    if (_active == this) _active = null;
    WidgetsBinding.instance.removeObserver(this);
    player.removeListener(_onPlayerChanged);
    final disposal = player.dispose().catchError((Object error) {
      debugPrint('Diary video player disposal failed: $error');
    });
    _disposal = disposal;
    if (trackPendingRelease) {
      _pendingRelease = disposal;
      unawaited(
        disposal.whenComplete(() {
          if (identical(_pendingRelease, disposal)) {
            _pendingRelease = null;
          }
        }),
      );
    }
    super.dispose();
  }

  /// [source] 可以是本地路径、`file://` / `http(s)://` 地址，或 Android 的
  /// `content://` 地址（“这天的照片”预览直接播放相册里的视频，不复制）。
  static VideoPlayerController _createPlayer(String source) {
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return VideoPlayerController.networkUrl(uri);
    }
    if (uri != null && uri.scheme == 'content') {
      return VideoPlayerController.contentUri(uri);
    }
    return VideoPlayerController.file(
      uri?.scheme == 'file' ? File.fromUri(uri!) : File(source),
    );
  }
}
