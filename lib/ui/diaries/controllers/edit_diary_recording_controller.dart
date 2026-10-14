// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// Commits a completed recording to the current document. A close/navigation
/// during asynchronous file finalization invalidates this panel generation;
/// its file is then removed instead of being attached to a different draft.
extension EditDiaryRecordingFlow on EditDiaryController {
  Future<void> startRecording() async {
    await DiaryAudioPlayerController.pauseActive();
    await DiaryVideoPlayerController.pauseActive();
    if (!_state.mounted || !_state._recordingPanelOpen) return;
    await _state._recordingController.start();
    // 真正进入录音（权限通过、原生会话建立）才震一下，确认“已经在录”；失败时
    // 面板状态行会给出原因，不再额外震动。
    if (_state.mounted &&
        _state._recordingController.phase == DiaryRecordingPhase.recording) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  Future<void> finishRecording() async {
    final generation = _state._recordingPanelGeneration;
    final selection =
        _state._recordingSelection ?? const TextSelection.collapsed(offset: -1);
    final recording = await _state._recordingController.finish();
    if (recording == null) return;
    if (!_state.mounted ||
        !_state._recordingPanelOpen ||
        generation != _state._recordingPanelGeneration) {
      await const DiaryAudioStorageService().deleteManagedRecording(
        recording.path,
      );
      return;
    }
    try {
      insertDiaryRecording(
        controller: _state._contentController,
        selection: selection,
        recording: recording,
      );
      // 录音已插入正文：轻震确认结束动作生效。
      unawaited(HapticFeedback.lightImpact());
      _state.setState(() {
        _state._recordingPanelOpen = false;
        _state._recordingSelection = null;
      });
    } catch (_) {
      await const DiaryAudioStorageService().deleteManagedRecording(
        recording.path,
      );
      if (!_state.mounted) return;
      await HomeHintVisibilityScope.showTrackedSnackBar(
        context: _state.context,
        snackBar: SnackBar(
          content: Text(_state.context.l10n.recordingSaveFailed),
        ),
      );
    }
  }
}
