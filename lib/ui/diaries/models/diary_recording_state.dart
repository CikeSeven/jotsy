enum DiaryRecordingPhase { idle, preparing, recording, paused, finishing }

enum DiaryRecordingFailure { permissionDenied, recordingFailed, saveFailed }

/// 控制器采样麦克风振幅的固定节拍。
///
/// 声纹以“每个采样一根柱”的方式滚动，滚动速度必须与该节拍对齐，否则新柱滑入的
/// 节奏会与采样脱节（过快则每根柱滑完要停顿，过慢则越积越多）。
const Duration recordingAmplitudeSamplePeriod = Duration(milliseconds: 120);

/// 面板据以排版的稳定阶段（只会是 idle / recording / paused）。
///
/// `preparing` / `finishing` 不是稳定阶段，而是“从某个阶段出发的短暂等待”：
/// 暂停、继续都会先经过 `preparing`，此时若把它当作“没有会话”处理，整块计时与
/// 控制区会在原生调用返回前的几十毫秒内塌缩再恢复，面板高度随之抖动。因此过渡
/// 态沿用 [previousSettled]，是否可交互由调用方根据 [phase] 另行判断。
DiaryRecordingPhase settleRecordingPhase(
  DiaryRecordingPhase phase,
  DiaryRecordingPhase previousSettled,
) => switch (phase) {
  DiaryRecordingPhase.preparing ||
  DiaryRecordingPhase.finishing => previousSettled,
  _ => phase,
};

String formatRecordingDuration(Duration duration) {
  final seconds = duration.inSeconds;
  final minutes = seconds ~/ 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}
