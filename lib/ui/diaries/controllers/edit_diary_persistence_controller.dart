// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 编辑页持久化装配：把输入映射为快照，协调自动保存、手动保存与退出；
/// 数据库写入失败时停留在页面并给出原有错误提示，保留输入供重试。
///
/// 两种保存方式（设置 → 编辑器设置 →「编辑行为」的“手动保存修改”，
/// `DiaryEditPrefs`，只管编辑已有日记，新建页始终存草稿箱）：
/// - 自动保存（默认）：改了就防抖写库；返回、切后台、被别的页面盖住、打开
///   别的页面与分享导出前都先补存（[flushEditAutoSave]），返回不弹询问框。
/// - 手动保存：只在顶栏“保存”（桌面 Ctrl / ⌘ + S，[saveEditManually]）与
///   询问框的“保存并退出”时写库。返回时有未保存的修改先问“取消 / 退出 /
///   保存并退出”（[_settleBeforeLeaving]）；切后台、被盖住、打开别的页面、
///   分享导出、AI 回应与删除都不写库，只等进行中的保存（[settleEditAutoSave]），
///   未保存的修改留在页面上，分享导出的是上次保存的版本。
extension EditDiaryPersistenceFlow on EditDiaryController {
  void initializeEditAutoSave() {
    _editAutoSave.initialize(_captureEditSnapshot());
  }

  /// 有修改：自动保存时防抖写库，手动保存时只更新“有没有未保存的修改”。
  void scheduleEditAutoSave() {
    if (_state._isEditEntry && _state._initialized) {
      _editAutoSave.schedule();
    }
  }

  /// 立即写下当前内容（自动保存的补存，也是手动保存的“保存”本身）。
  Future<bool> flushEditAutoSave() => _editAutoSave.flush();

  /// 编辑已有日记且设置为手动保存。
  bool get manualEditSave => _state._isEditEntry && _state._manualSave;

  /// 手动保存时有没有未保存的修改（当场比对，见 `hasUnsavedChanges`）。
  bool get hasUnsavedEditChanges =>
      manualEditSave && _editAutoSave.hasUnsavedChanges;

  /// 打开别的页面、分享导出、删除之前：自动保存时补存；手动保存时不写库，
  /// 只等进行中的保存（用户刚点了保存）落盘。返回 false 表示保存失败。
  Future<bool> settleEditAutoSave() =>
      manualEditSave ? _editAutoSave.settle() : _editAutoSave.flush();

  /// 顶栏“保存”与桌面 Ctrl / ⌘ + S：写库期间停用顶栏与工具按钮（同返回时
  /// 的补存），成功后“保存”按钮短暂显示对勾；失败时自动保存给出提示，修改
  /// 留在页面上可以再存。
  Future<void> saveEditManually() async {
    if (!manualEditSave || !_state._initialized || _state._saving) return;
    _state.setState(() => _state._saving = true);
    final bool saved;
    try {
      saved = await flushEditAutoSave();
    } finally {
      if (_state.mounted) _state.setState(() => _state._saving = false);
    }
    if (saved && _state.mounted) _state._flashEditSaved();
  }

  EditDiarySnapshot _captureEditSnapshot() {
    if (_state._panelMetadataDirty) {
      _state._metadataJson = _buildMetadataJsonForEdit();
      _state._panelMetadataDirty = false;
    }
    return EditDiarySnapshot(
      title: _state._titleController.text,
      contentDocJson: _state._currentContentDocJson,
      contentText: _state._currentContentText,
      cover: _state._meta.value.cover,
      metadataJson: _state._metadataJson.trim(),
      selectedTagIds: _state._meta.value.tagIds,
      createdAt: _state._draftPublishAt,
      notebookIds: _state._notebookIdsDirty
          ? _state._meta.value.notebookIds.toList(growable: false)
          : null,
    );
  }

  Future<void> _persistEditSnapshot(EditDiarySnapshot snapshot) async {
    if (!isValidMetadataJsonObject(snapshot.metadataJson)) {
      throw FormatException(_state.context.l10n.autoT0203);
    }
    // 已有笔记允许暂时清空标题与正文：编辑中的空内容也属于用户的修改，
    // 不应因新建页的非空校验而悄悄恢复旧文。
    final storedAt = await _state.ref
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
          // null：用户没改过日记本，不动关联（仍在的本子保留章节与位置）。
          notebookIds: snapshot.notebookIds,
        );
    // 阅读式页头页尾按写下的内容刷新（借用的首图、字数、最后编辑于），并记下
    // 库里这一版的更新时间（回到前台时据此判断别处有没有改过）。
    _state._onReadingSaved(snapshot, storedAt);
  }

  /// 离开编辑页之前（返回、日记本胶囊回到首页）：手动保存且有未保存的
  /// 修改时先问——取消留在本页，退出放弃这些修改，保存并退出先写库；
  /// 其余情况补存。写库期间 `_saving` 为真，停用顶栏与工具按钮、不可重入。
  /// 返回能不能离开（写库失败时为 false，自动保存已给出提示）。
  Future<bool> _settleBeforeLeaving() async {
    if (hasUnsavedEditChanges) {
      final decision = await showUnsavedChangesDialog(_state.context);
      if (!_state.mounted) return false;
      switch (decision) {
        case UnsavedChangesDecision.cancel:
          return false;
        case UnsavedChangesDecision.discard:
          // 只等用户先前点的保存（若还在写），这次的修改不写。
          return _editAutoSave.settle();
        case UnsavedChangesDecision.saveAndExit:
          break;
      }
    }
    _state.setState(() => _state._saving = true);
    try {
      return await flushEditAutoSave();
    } finally {
      if (_state.mounted) _state.setState(() => _state._saving = false);
    }
  }

  /// 桌面关闭窗口时（手动保存且有未保存的修改，见
  /// `DebouncedAutoSaveController.confirmManualExit`）：同返回一样询问。
  Future<bool> _confirmDesktopExit() async {
    if (!_state.mounted || _state._saving) return false;
    return _settleBeforeLeaving();
  }

  Future<void> attemptExit() async {
    if (_state._saving) return;
    if (_state._recordingPanelOpen) {
      _state._closeRecordingPanel();
      return;
    }
    if (_state._aiPanelOpen) {
      closeAiPanel();
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
    // 新建页“返回时直接发表”：写库后退场（见 EditDiaryCreateLeaveFlow）。
    if (_state._isCreateEntry &&
        _state.ref.read(diaryCreatePrefsProvider).publishOnLeave) {
      await leaveCreateEntryPublishing();
      return;
    }
    final leave = await _settleBeforeLeaving();
    if (leave && _state.mounted) Navigator.of(_state.context).pop();
  }

  void dispose() {
    _editAutoSave.dispose();
    _draftAutoSave.dispose();
  }
}
