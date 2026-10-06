import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 模拟原生播放器事件，验证生命周期及控件交互，不启动设备解码器。
class FakeVideoPlayer extends VideoPlayerController {
  FakeVideoPlayer()
    : super.networkUrl(Uri.parse('https://example.invalid/video.mp4'));

  Completer<void>? initializationGate;
  bool failInitialization = false;
  bool failPlayback = false;
  int playCount = 0;
  int pauseCount = 0;
  bool wasDisposed = false;

  @override
  Future<void> initialize() async {
    await initializationGate?.future;
    if (failInitialization) throw StateError('unsupported video');
    if (wasDisposed) return;
    value = const VideoPlayerValue(
      duration: Duration(seconds: 12),
      size: Size(320, 180),
      isInitialized: true,
    );
  }

  @override
  Future<void> play() async {
    if (failPlayback) throw StateError('decoder failed');
    playCount++;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    value = value.copyWith(position: position);
  }

  @override
  Future<void> dispose() async {
    wasDisposed = true;
    await super.dispose();
  }
}
