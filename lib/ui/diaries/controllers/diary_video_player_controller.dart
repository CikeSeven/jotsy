import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 拥有一个正文视频的异步初始化/播放状态，并在后台、退出和切换视频时暂停。
/// 不自动播放；销毁后的原生回调不能再通知已经离开的编辑器或预览页。
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
  Future<void>? _initialization;
  bool _disposed = false;
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

  @override
  void dispose() {
    _disposed = true;
    if (_active == this) _active = null;
    WidgetsBinding.instance.removeObserver(this);
    player.removeListener(_onPlayerChanged);
    unawaited(
      player.dispose().catchError((Object error) {
        debugPrint('Diary video player disposal failed: $error');
      }),
    );
    super.dispose();
  }

  static VideoPlayerController _createPlayer(String source) {
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return VideoPlayerController.networkUrl(uri);
    }
    return VideoPlayerController.file(
      uri?.scheme == 'file' ? File.fromUri(uri!) : File(source),
    );
  }
}
