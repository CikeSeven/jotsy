import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';

import '../../../support/fake_video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fullscreen retains the player while backgrounding pauses playback',
    () async {
      final player = FakeVideoPlayer();
      final controller = DiaryVideoPlayerController(
        source: '/video.mp4',
        player: player,
      );
      addTearDown(controller.dispose);
      expect(controller.enterFullscreen(), isFalse);
      await controller.initialize();
      await controller.toggle();
      await controller.seek(const Duration(seconds: 5));
      expect(controller.enterFullscreen(), isTrue);
      expect(controller.enterFullscreen(), isFalse);
      expect(controller.isPlaying, isTrue);
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(controller.isPlaying, isFalse);
      controller.leaveFullscreen();
      expect(controller.isFullscreen, isFalse);
      expect(player.value.position, const Duration(seconds: 5));
      expect(player.wasDisposed, isFalse);
    },
  );

  test(
    'video initializes without autoplay and supports play pause seek and restart',
    () async {
      final player = FakeVideoPlayer();
      final controller = DiaryVideoPlayerController(
        source: '/video.mp4',
        player: player,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.isLoading, isFalse);
      expect(player.playCount, 0);
      await controller.toggle();
      expect(controller.isPlaying, isTrue);
      await controller.seek(const Duration(seconds: 4));
      expect(player.value.position, const Duration(seconds: 4));
      await controller.toggle();
      expect(controller.isPlaying, isFalse);
      await controller.seek(const Duration(seconds: 99));
      expect(player.value.position, const Duration(seconds: 12));
      await controller.toggle();
      expect(player.value.position, Duration.zero);
      expect(controller.isPlaying, isTrue);
    },
  );

  test('starting another video pauses the previous player', () async {
    final first = DiaryVideoPlayerController(
      source: '/one.mp4',
      player: FakeVideoPlayer(),
    );
    final second = DiaryVideoPlayerController(
      source: '/two.mp4',
      player: FakeVideoPlayer(),
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.initialize();
    await second.initialize();
    await first.toggle();
    await second.toggle();
    expect(first.isPlaying, isFalse);
    expect(second.isPlaying, isTrue);
    second.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(second.isPlaying, isFalse);
  });

  test(
    'unplayable videos report failure and end their loading state',
    () async {
      final player = FakeVideoPlayer()..failInitialization = true;
      final controller = DiaryVideoPlayerController(
        source: '/broken.mp4',
        player: player,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.hasFailed, isTrue);
      expect(controller.isLoading, isFalse);
      await controller.toggle();
      expect(player.playCount, 0);
    },
  );

  test('late video initialization cannot notify a disposed editor', () async {
    final gate = Completer<void>();
    final player = FakeVideoPlayer()..initializationGate = gate;
    final controller = DiaryVideoPlayerController(
      source: '/pending.mp4',
      player: player,
    );
    var changes = 0;
    controller.addListener(() => changes++);
    final initialized = controller.initialize();
    controller.dispose();
    gate.complete();
    await initialized;
    expect(changes, 0);
    expect(player.wasDisposed, isTrue);
  });
}
