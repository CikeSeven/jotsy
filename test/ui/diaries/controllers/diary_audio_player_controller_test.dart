import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/ui/diaries/controllers/diary_audio_player_controller.dart';

import '../../../support/fake_audio_player.dart';

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
