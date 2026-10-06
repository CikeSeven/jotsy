import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:node_diary/core/services/audio_playback_service.dart';

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
