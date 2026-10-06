// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

extension EditDiaryMediaFlow on EditDiaryController {
  Future<void> importMedia(DiaryMediaKind kind) async {
    if (_state._saving || _state._recordingPanelOpen) return;
    final controller = _state._contentController;
    final route = ModalRoute.of(_state.context);
    final outcome = await _state._mediaImportController.pickAndInsert(
      controller: controller,
      kind: kind,
      isCurrent: () =>
          _state.mounted &&
          identical(_state._contentController, controller) &&
          !_state._saving &&
          (route?.isCurrent ?? true),
    );
    if (!_state.mounted) return;
    final l10n = _state.context.l10n;
    final message = switch (outcome) {
      DiaryMediaImportOutcome.failed => l10n.diaryMediaImportFailed,
      DiaryMediaImportOutcome.unsupported => l10n.diaryMediaImportUnsupported,
      _ => null,
    };
    if (message == null) return;
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(content: Text(message)),
    );
  }
}
