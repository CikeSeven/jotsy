import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/services/audio_playback_service.dart';
import 'package:node_diary/ui/diaries/controllers/diary_audio_player_controller.dart';

void main() {
  test(
    'local recording playback pauses resumes seeks and restarts after completion',
    () async {
      final player = FakeAudioPlayer();
      final controller = DiaryAudioPlayerController(
        recording: const DiaryAudioAttachment(
          path: '/documents/diary_recordings/entry.m4a',
          duration: Duration(seconds: 12),
        ),
        player: player,
      );
      addTearDown(controller.dispose);

      await controller.toggle();
      expect(player.path, '/documents/diary_recordings/entry.m4a');
      expect(controller.isPlaying, isTrue);
      await controller.toggle();
      expect(controller.isPlaying, isFalse);
      await controller.toggle();
      expect(player.resumeCalls, 1);
      await controller.seek(const Duration(seconds: 4));
      expect(controller.position, const Duration(seconds: 4));
      player.stateController.add(PlayerState.completed);
      expect(controller.position, Duration.zero);
      await controller.toggle();
      expect(player.playCalls, 2);
    },
  );

  test(
    'unplayable file reports a playback failure and remains retryable',
    () async {
      final player = FakeAudioPlayer()..fail = true;
      final controller = DiaryAudioPlayerController(
        recording: const DiaryAudioAttachment(
          path: '/documents/diary_recordings/missing.m4a',
          duration: Duration(seconds: 2),
        ),
        player: player,
      );
      addTearDown(controller.dispose);
      await controller.toggle();
      expect(controller.hasFailed, isTrue);
      expect(controller.isLoading, isFalse);
      player.fail = false;
      await controller.toggle();
      expect(controller.hasFailed, isFalse);
      expect(controller.isPlaying, isTrue);
    },
  );
}

class FakeAudioPlayer implements AudioPlaybackService {
  final stateController = StreamController<PlayerState>.broadcast(sync: true);
  final positionController = StreamController<Duration>.broadcast(sync: true);
  final durationController = StreamController<Duration>.broadcast(sync: true);
  bool fail = false;
  String? path;
  int playCalls = 0;
  int resumeCalls = 0;
  @override
  Stream<PlayerState> get states => stateController.stream;
  @override
  Stream<Duration> get positions => positionController.stream;
  @override
  Stream<Duration> get durations => durationController.stream;
  @override
  Future<void> play(String path) async {
    if (fail) throw StateError('missing file');
    this.path = path;
    playCalls++;
    stateController.add(PlayerState.playing);
  }

  @override
  Future<void> pause() async => stateController.add(PlayerState.paused);
  @override
  Future<void> resume() async {
    resumeCalls++;
    stateController.add(PlayerState.playing);
  }

  @override
  Future<void> seek(Duration position) async =>
      positionController.add(position);
  @override
  Future<void> dispose() async {
    await stateController.close();
    await positionController.close();
    await durationController.close();
  }
}
