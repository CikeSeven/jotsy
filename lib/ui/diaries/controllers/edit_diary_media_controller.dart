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

extension EditDiaryDayPhotosFlow on EditDiaryController {
  /// 把“这天拍的照片”里勾选的照片插入正文光标处。
  ///
  /// 复用媒体导入链路（复制到日记私有目录 → 插入 → 失败回滚），只是文件
  /// 来源换成相册里已选好的照片，不再打开系统选择器。照片在打开页面后
  /// 被删掉时跳过并提示；全部成功插入的照片在提示条里标为“已插入”。
  /// 无论成败都释放插件为读取原图生成的缓存副本。
  Future<void> insertDayPhotos() async {
    if (_state._saving || _state._recordingPanelOpen) return;
    final dayPhotos = _state._dayPhotos;
    final photos = dayPhotos.selectedPhotos;
    if (photos.isEmpty) return;
    final library = dayPhotos.library;
    final controller = _state._contentController;
    final route = ModalRoute.of(_state.context);
    final missing = <DayPhoto>{};
    final DiaryMediaImportOutcome outcome;
    try {
      outcome = await _state._mediaImportController.pickAndInsert(
        controller: controller,
        kind: DiaryMediaKind.image,
        isCurrent: () =>
            _state.mounted &&
            identical(_state._contentController, controller) &&
            !_state._saving &&
            (route?.isCurrent ?? true),
        picker: (_) async {
          final files = <PlatformFile>[];
          for (final photo in photos) {
            final file = await library.fileOf(photo);
            if (file == null) {
              missing.add(photo);
            } else {
              files.add(file);
            }
          }
          return files;
        },
      );
    } finally {
      await library.releaseFiles();
    }
    if (!_state.mounted) return;
    if (outcome == DiaryMediaImportOutcome.inserted) {
      dayPhotos.markInserted(photos.where((p) => !missing.contains(p)));
    }
    final l10n = _state.context.l10n;
    final message = switch (outcome) {
      DiaryMediaImportOutcome.failed => l10n.diaryMediaImportFailed,
      _ when missing.isNotEmpty => l10n.diaryDayPhotosMissing(missing.length),
      _ => null,
    };
    if (message == null) return;
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(content: Text(message)),
    );
  }

  /// 把“这天拍的照片”里的一张设为日记封面。
  ///
  /// 封面拷贝到封面私有目录（与发布页选封面同一条链路），写进新建草稿并
  /// 排程草稿保存；发布页打开即显示这张封面，仍可更换。原图只读，结束后
  /// 释放插件为读取原图生成的缓存副本。
  Future<void> setDayPhotoCover(DayPhoto photo) async {
    final actions = _state._metaActions;
    if (_state._saving || actions.importingCover.value) return;
    final dayPhotos = _state._dayPhotos;
    final library = dayPhotos.library;
    var applied = false;
    try {
      final file = await library.fileOf(photo);
      if (!_state.mounted) return;
      final path = file?.path;
      if (path == null) {
        _showHint(_state.context.l10n.diaryDayPhotosMissing(1));
        return;
      }
      applied = await actions.setCoverFromFile(_state.context, path);
    } catch (error) {
      debugPrint('Day photo cover failed: $error');
      if (_state.mounted) {
        _showHint(_state.context.l10n.publishCoverImportFailed);
      }
    } finally {
      await library.releaseFiles();
    }
    final cover = _state._meta.value.cover;
    if (!applied || !_state.mounted || cover == null) return;
    dayPhotos.markCover(photo, cover);
    scheduleCreateDraftAutoSave();
    _showHint(_state.context.l10n.diaryDayPhotosCoverSet);
  }

  /// 取消由“这天的照片”设定的封面；角标经 _onMetaChanged 同步消失。
  void clearDayPhotoCover() {
    if (_state._saving) return;
    _state._metaActions.clearCover();
    scheduleCreateDraftAutoSave();
  }
}
