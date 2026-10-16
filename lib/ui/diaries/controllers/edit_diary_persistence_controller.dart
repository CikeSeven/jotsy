// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 编辑页持久化装配：把输入映射为快照，协调自动保存与退出；数据库写入
/// 失败时停留在页面并给出原有错误提示，保留输入供重试，不展示保存确认框。
extension EditDiaryPersistenceFlow on EditDiaryController {
  void initializeEditAutoSave() {
    _editAutoSave.initialize(_captureEditSnapshot());
  }

  void scheduleEditAutoSave() {
    if (_state._isEditEntry && _state._initialized) {
      _editAutoSave.schedule();
    }
  }

  Future<bool> flushEditAutoSave() => _editAutoSave.flush();

  EditDiarySnapshot _captureEditSnapshot() {
    if (_state._panelMetadataDirty) {
      _state._metadataJson = _buildMetadataJsonForEdit();
      _state._panelMetadataDirty = false;
    }
    return EditDiarySnapshot(
      title: _state._titleController.text,
      contentDocJson: _state._currentContentDocJson,
      contentText: _state._currentContentText,
      cover: normalizeOptionalText(_state._draftCover),
      metadataJson: _state._metadataJson.trim(),
      selectedTagIds: _state._selectedTagIds,
      createdAt: _state._draftPublishAt,
    );
  }

  Future<void> _persistEditSnapshot(EditDiarySnapshot snapshot) async {
    if (!isValidMetadataJsonObject(snapshot.metadataJson)) {
      throw FormatException(_state.context.l10n.autoT0203);
    }
    // 已有笔记允许暂时清空标题与正文：编辑中的空内容也属于用户的修改，
    // 不应因新建页的非空校验而悄悄恢复旧文。
    await _state.ref
        .read(appDatabaseProvider)
        .updateDiary(
          diaryId: _state.widget.diaryId!,
          title: snapshot.title,
          contentDocJson: snapshot.contentDocJson,
          contentText: snapshot.contentText,
          cover: snapshot.cover,
          metadataJson: snapshot.metadataJson,
          tagIds: snapshot.selectedTagIds.toList(),
          createdAt: snapshot.createdAt,
        );
  }

  Future<void> attemptExit() async {
    if (_state._saving) return;
    if (_state._recordingPanelOpen) {
      _state._closeRecordingPanel();
      return;
    }
    // 返回先退出面板子页或收起面板，再补存尚处于防抖窗口中的输入。
    if (_state._editPanelController.canPopInnerPage) {
      await _state._editPanelController.popInnerPage();
      return;
    }
    if (_state._editPanelController.isExpanded) {
      await _state._editPanelController.collapse();
      return;
    }
    _state.setState(() => _state._saving = true);
    try {
      final saved = await flushEditAutoSave();
      if (saved && _state.mounted) {
        Navigator.of(_state.context).pop();
      }
    } finally {
      if (_state.mounted) _state.setState(() => _state._saving = false);
    }
  }

  void dispose() => _editAutoSave.dispose();
}
