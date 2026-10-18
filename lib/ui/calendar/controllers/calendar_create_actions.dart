part of 'package:node_diary/ui/calendar/pages/calendar_page.dart';

/// 从日历新建日记：草稿分流（继续上次草稿或新建空白）后进入编辑页，发表
/// 日期取日历上的日期，未来日期可预设为时间胶囊。
extension _CalendarCreateActions on _CalendarPageController {
  /// 从日历进入新建流程：
  /// - 先处理草稿分流；
  /// - 最终进入创建页并附带 [day]（默认选中日期）作为创建日期覆盖值；
  /// - [capsuleUnlockAt] 非空时预设为在该日解封的时间胶囊（未来日期的
  ///   “写给这一天的时间胶囊”）。
  Future<void> openCreateEditorWithDraftPrompt({
    DateTime? day,
    DateTime? capsuleUnlockAt,
  }) async {
    final targetDay = DateUtils.dateOnly(day ?? _state._selectedDay);
    final database = _state.ref.read(appDatabaseProvider);
    await _state.ref.read(diaryDraftLegacyMigrationProvider.future);
    final latestDraft = (await database.getRecentDiaryDrafts(1)).firstOrNull;
    if (!_state.mounted) {
      return;
    }

    String? createDraftId;
    if (latestDraft != null) {
      final decision = await _showCreateDraftDecisionDialog();
      if (!_state.mounted || decision == null) {
        return;
      }
      // 新建空白不再删除旧草稿：它留在草稿箱里。
      if (decision == _CalendarCreateDraftDecision.continueEditing) {
        createDraftId = latestDraft.draftId;
      }
    }

    if (!_state.mounted) {
      return;
    }

    await Navigator.of(_state.context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return EditDiaryPage(
            entryMode: EditDiaryEntryMode.create,
            createDraftId: createDraftId,
            createDateOverride: targetDay,
            createCapsuleUnlockAt: capsuleUnlockAt,
          );
        },
      ),
    );
  }

  Future<_CalendarCreateDraftDecision?> _showCreateDraftDecisionDialog() {
    return showDialog<_CalendarCreateDraftDecision>(
      context: _state.context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(_state.context.l10n.autoT0081),
          content: Text(_state.context.l10n.autoT0209),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(_CalendarCreateDraftDecision.newEmpty);
              },
              child: Text(_state.context.l10n.autoT0082),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(_CalendarCreateDraftDecision.continueEditing);
              },
              child: Text(_state.context.l10n.autoT0083),
            ),
          ],
        );
      },
    );
  }
}
