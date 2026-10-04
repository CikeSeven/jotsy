enum DiaryRecordingPhase { idle, preparing, recording, paused, finishing }

enum DiaryRecordingFailure { permissionDenied, recordingFailed, saveFailed }

String formatRecordingDuration(Duration duration) {
  final seconds = duration.inSeconds;
  final minutes = seconds ~/ 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}
