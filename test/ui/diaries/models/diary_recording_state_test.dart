import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';

void main() {
  group('settleRecordingPhase', () {
    test('stable phases settle to themselves', () {
      for (final phase in [
        DiaryRecordingPhase.idle,
        DiaryRecordingPhase.recording,
        DiaryRecordingPhase.paused,
      ]) {
        for (final previous in DiaryRecordingPhase.values) {
          expect(settleRecordingPhase(phase, previous), phase);
        }
      }
    });

    test('transitional phases keep the previous settled phase', () {
      for (final transitional in [
        DiaryRecordingPhase.preparing,
        DiaryRecordingPhase.finishing,
      ]) {
        for (final previous in [
          DiaryRecordingPhase.idle,
          DiaryRecordingPhase.recording,
          DiaryRecordingPhase.paused,
        ]) {
          expect(settleRecordingPhase(transitional, previous), previous);
        }
      }
    });

    test('pause then resume never passes through the idle layout', () {
      // recording -> preparing(pause) -> paused -> preparing(resume) -> recording
      var settled = DiaryRecordingPhase.recording;
      for (final phase in [
        DiaryRecordingPhase.preparing,
        DiaryRecordingPhase.paused,
        DiaryRecordingPhase.preparing,
        DiaryRecordingPhase.recording,
      ]) {
        settled = settleRecordingPhase(phase, settled);
        expect(settled, isNot(DiaryRecordingPhase.idle));
      }
    });

    test('first start waits in the idle layout until capture begins', () {
      var settled = DiaryRecordingPhase.idle;
      settled = settleRecordingPhase(DiaryRecordingPhase.preparing, settled);
      expect(settled, DiaryRecordingPhase.idle);
      settled = settleRecordingPhase(DiaryRecordingPhase.recording, settled);
      expect(settled, DiaryRecordingPhase.recording);
    });
  });

  group('formatRecordingDuration', () {
    test('pads minutes and seconds', () {
      expect(formatRecordingDuration(Duration.zero), '00:00');
      expect(formatRecordingDuration(const Duration(seconds: 65)), '01:05');
    });

    test('truncates fractions and lets minutes exceed two digits', () {
      expect(
        formatRecordingDuration(const Duration(milliseconds: 59900)),
        '00:59',
      );
      expect(formatRecordingDuration(const Duration(seconds: 3725)), '62:05');
    });
  });
}
