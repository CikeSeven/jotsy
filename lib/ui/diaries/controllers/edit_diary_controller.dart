// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 编辑页业务控制器。
///
/// 职责边界：
/// - 新建模式：草稿箱里这一份草稿的自动保存、续写恢复与发布后删除；
/// - 协调已有笔记自动保存、删除与新建发布跳转链路；
/// - 不构建 UI，仅协调页面状态与数据层。
class EditDiaryController {
  EditDiaryController(this._state) {
    _editAutoSave = DebouncedAutoSaveController<EditDiarySnapshot>(
      debounce: const Duration(milliseconds: 500),
      readSnapshot: _captureEditSnapshot,
      writeSnapshot: _persistEditSnapshot,
      onError: (error) {
        if (_state.mounted) {
          _showHint(_state.context.l10n.autoT0087(error.toString()));
        }
      },
    );
    _draftAutoSave = DebouncedAutoSaveController<NewDiaryDraftSnapshot>(
      debounce: const Duration(milliseconds: 1300),
      // 只套用了模板、还没动过的内容不算草稿（见 snapshotFor）。
      readSnapshot: () =>
          _state._templates.snapshotFor(_state._currentCreateDraft),
      writeSnapshot: _persistCreateDraft,
      // 草稿写入失败不打断输入：快照保持未存，下一次输入、返回或切后台重试。
      onError: (error) => debugPrint('Create draft autosave failed: $error'),
    );
  }

  /// 页面状态引用，承载控制器需要读写的输入与临时状态。
  final _EditDiaryPageState _state;
  late final DebouncedAutoSaveController<EditDiarySnapshot> _editAutoSave;
  late final DebouncedAutoSaveController<NewDiaryDraftSnapshot> _draftAutoSave;

  /// 编辑态发表时间文案（精确到分钟）；详情回填前为 null。
  String? get publishTimeLabelForEdit {
    final publishAt = _state._draftPublishAt;
    if (publishAt == null) {
      return null;
    }
    return _state.context.l10n.formatDateTimeMinute(publishAt);
  }

  /// 替换正文控制器时同步管理监听，避免旧控制器泄漏。
  void replaceContentController(quill.QuillController nextController) {
    _state._mediaImportController.cancel();
    _state._contentController.removeListener(onCreateDraftInputChanged);
    _state._contentController.dispose();
    _state._contentController = nextController;
    _state._contentController.addListener(onCreateDraftInputChanged);
    _state._caretFollow.attach(nextController);
  }

  /// 新建模式保存草稿，已有笔记直接自动保存；详情回填阶段不触发写入。
  void onCreateDraftInputChanged() {
    if (_state._isCreateEntry) {
      _state._templates.onEditorChanged();
      scheduleCreateDraftAutoSave();
      return;
    }
    scheduleEditAutoSave();
  }

  /// 1.3 秒防抖自动保存草稿；续写的草稿在恢复完成前不排程（见
  /// [prepareCreateEntry]）。
  void scheduleCreateDraftAutoSave() => _draftAutoSave.schedule();

  /// 立即补存防抖窗口里的输入（返回、切后台、页面销毁时调用）。
  Future<bool> flushCreateDraft() => _draftAutoSave.flush();

  /// 写入草稿表：有内容时新建或更新这一份；内容删光时删除这一行，但保留
  /// id——接着再写字仍是同一份草稿（按同一 id 重新插入），不会多出一份。
  ///
  /// 页面卸载后仍可能执行（返回时补存），只用页面初始化时缓存的数据库。
  Future<void> _persistCreateDraft(NewDiaryDraftSnapshot snapshot) async {
    final database = _state._database;
    if (!snapshot.hasContent) {
      final draftId = _state._createDraftId;
      if (draftId != null) await database.deleteDiaryDrafts([draftId]);
      return;
    }
    _state._createDraftId = await database.saveDiaryDraft(
      draftId: _state._createDraftId,
      title: snapshot.title,
      contentText: snapshot.contentText,
      payload: snapshot.payload,
    );
  }

  /// 新建页初始化：先沿用上次选择的地址层级，再按需恢复草稿。两步串行，
  /// 草稿里保存的层级一定覆盖默认值，而不依赖两个异步回调的执行顺序。
  /// 新建页不展示面板，层级只随草稿带进发布页，因此无需 setState。
  ///
  /// 自动保存的基线在内容就位后才设定：新建空白取空白页，续写取恢复后的
  /// 内容。在那之前输入不会排程写入——否则恢复前打的几个字可能先把这份
  /// 草稿覆盖成只剩这几个字；只打开不修改也不会刷新草稿的编辑时间。
  Future<void> prepareCreateEntry({required String? draftId}) async {
    final precision = await DiaryLocationPreference.load(_state.ref);
    if (!_state.mounted) return;
    _state._meta.setPrecision(precision);
    if (draftId != null) {
      final restored = await restoreCreateDraft(draftId);
      if (!_state.mounted) return;
      // 这份草稿已不在（例如刚在别处删除）：当作新建空白，另存一份新草稿。
      if (!restored) _state._createDraftId = null;
    } else {
      // 入口带来的模板或自动套用的模板要算进基线：原样未动时它不是草稿。
      await applyInitialTemplate();
      if (!_state.mounted) return;
    }
    _draftAutoSave.initialize(_state._currentCreateDraft.toSnapshot());
    // 等待期间若已输入，基线已含这些内容；再排一次，让它们按正常防抖落盘。
    _draftAutoSave.schedule();
  }

  /// 从草稿箱读出 [draftId] 并填进编辑页；返回是否恢复成功。
  Future<bool> restoreCreateDraft(String draftId) async {
    final database = _state._database;
    final row = await database.getDiaryDraft(draftId);
    if (row == null || !_state.mounted) {
      return false;
    }

    try {
      final decoded = jsonDecode(row.payload);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      final restoredDraft = NewDiaryDraft.fromJson(
        decoded.cast<String, Object?>(),
      );
      // 草稿可能放了很久，期间被删除的标签不能再带进发布页。
      final existingTagIds = (await database.watchAllTags().first)
          .map((tag) => tag.id)
          .toSet();
      if (!_state.mounted) {
        return false;
      }

      // 优先恢复富文本文档；若 JSON 不可用则降级为纯文本，保证可读可编辑。
      quill.Document restoredDocument;
      try {
        restoredDocument = decodeDiaryContentToDocument(
          restoredDraft.contentDocJson,
        );
      } catch (_) {
        restoredDocument = documentFromPlainText(restoredDraft.contentText);
      }

      final restoredMeta = DiaryMetaDraft.fromNewDiaryDraft(
        restoredDraft.copyWith(
          selectedTagIds: restoredDraft.selectedTagIds
              .where(existingTagIds.contains)
              .toSet(),
        ),
      );
      _state.setState(() {
        _state._titleController.text = restoredDraft.title;
        _state._createDateOverride =
            restoredDraft.createdAtOverride ?? _state._createDateOverride;
        _state._metadataJson = restoredDraft.metadataJson;
        // 与发表日期覆盖值同一规则：草稿自带胶囊设置时以草稿为准，否则保留
        // 入口预设的解封日（见 EditDiaryPage.createCapsuleUnlockAt）。
        _state._meta.restore(
          restoredMeta.capsule == null
              ? restoredMeta.copyWith(capsule: _state._meta.value.capsule)
              : restoredMeta,
        );
        replaceContentController(
          quill.QuillController(
            document: restoredDocument,
            selection: const TextSelection.collapsed(offset: 0),
          ),
        );
      });
      _state._syncDayPhotos();
      return true;
    } catch (_) {
      // 草稿反序列化失败时静默忽略，避免阻断新建流程。
      return false;
    }
  }

  /// 发布成功后收尾：先关闭草稿自动保存并等进行中的写入结束，再删除这份
  /// 草稿。顺序不能反：防抖窗口里已开始的写入若晚于删除落盘，会把已发布的
  /// 草稿写回草稿箱。不依赖页面状态，页面被移除后继续完成。
  Future<void> _deletePublishedDraft() async {
    await _draftAutoSave.close();
    final draftId = _state._createDraftId;
    if (draftId != null) {
      await _state._database.deleteDiaryDrafts([draftId]);
    }
  }

  /// 保存前校验：至少需要标题或正文其一非空。
  bool validateDraft() {
    final title = _state._titleController.text.trim();
    if (title.isEmpty &&
        !diaryDocumentHasVisibleContent(_state._contentController.document)) {
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: _state.context,
          snackBar: SnackBar(content: Text(_state.context.l10n.autoT0086)),
        ),
      );
      return false;
    }
    if (!isValidMetadataJsonObject(_state._metadataJson)) {
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: _state.context,
          snackBar: SnackBar(content: Text(_state.context.l10n.autoT0203)),
        ),
      );
      return false;
    }
    return true;
  }

  /// 修改已发布日记的发表时间，与其他面板字段一样自动保存。
  ///
  /// 发表时间写入 created_at 而不在 metadata 里，所以只排程自动保存、不标记
  /// 面板脏位：标记会整体重组 metadata（刷新 generatedAt、设备信息等），改
  /// 时间不该波及这些字段。选回原来那一分钟时选择器原样返回旧值，快照不变，
  /// 不会写库，也就不会刷新“最后编辑”时间。
  Future<void> pickPublishAtForEdit() async {
    final current = _state._draftPublishAt;
    if (current == null || _state._saving) {
      return;
    }
    final picked = await showPublishTimePicker(
      _state.context,
      current: current,
    );
    if (picked == null || !_state.mounted) {
      return;
    }
    _state.setState(() => _state._draftPublishAt = picked);
    // 改到另一天：“这天的照片”随之换成新的日子（在事件回调里，不在 build 中）。
    _state._syncDayPhotos();
    scheduleEditAutoSave();
  }

  /// 软删除当前日记（仅编辑模式可用）。
  Future<void> softDelete() async {
    final diaryId = _state.widget.diaryId;
    if (diaryId == null || _state._saving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: _state.context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.autoT0094),
          content: Text(l10n.autoT0206),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(
                  dialogContext,
                ).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final db = _state.ref.read(appDatabaseProvider);
    await db.softDeleteDiary(diaryId);

    if (!_state.mounted) {
      return;
    }
    Navigator.of(_state.context).pop(true);
  }

  /// 发布成功、发布页即将退场时调用：删除这份草稿，并把编辑页静默移出路由栈。
  ///
  /// 必须赶在发布页退场之前：导航器只允许在上层路由静止且不透明时立即移除
  /// 下层路由，若等发布页开始退场再移除，会被推迟到退场结束——编辑页先露出
  /// 再瞬间消失。此前的做法是发布页退场后编辑页再 pop 一次，两段退场叠在
  /// 一起。现在发布页滑走时露出的直接是列表；新日记 id 作为编辑页的结果交给
  /// 打开者，列表据此播放新卡片的出现动画。草稿清理不依赖页面状态，页面被
  /// 移除后继续完成。
  void _handlePublished(String diaryId) {
    unawaited(_deletePublishedDraft());
    final route = ModalRoute.of(_state.context);
    if (route != null && route.isActive) {
      Navigator.of(_state.context).removeRoute(route, diaryId);
    }
  }

  /// 跳转到发布页，并在返回后回写发布页修改过的草稿上下文。
  Future<void> openPublishPage() async {
    if (!validateDraft()) {
      return;
    }

    final result = await Navigator.of(_state.context).push<Object>(
      MaterialPageRoute<Object>(
        builder: (BuildContext context) {
          return PublishDiaryPage(
            onPublished: _handlePublished,
            initialDraft: _state._currentCreateDraft,
          );
        },
      ),
    );

    if (!_state.mounted) {
      return;
    }

    if (result is NewDiaryDraft) {
      _state.setState(() {
        _state._createDateOverride =
            result.createdAtOverride ?? _state._createDateOverride;
        _state._metadataJson = result.metadataJson;
        _state._meta.restore(DiaryMetaDraft.fromNewDiaryDraft(result));
      });
      // 发布页可能改了发表日期：补写的那天随之变化。
      _state._syncDayPhotos();
      scheduleCreateDraftAutoSave();
    }
  }

  String _buildMetadataJsonForEdit({DateTime? generatedAt}) {
    return PublishMetadataComposer.composeDraft(
      draft: _state._meta.value,
      contentText: _state._currentContentText,
      generatedAt: generatedAt ?? DateTime.now(),
      // 编辑页面板不管胶囊与导入来源：沿用原 metadata 里的这些块。
      preserve: _decodeMetadataObject(_state._metadataJson),
    );
  }

  Map<String, Object?>? _decodeMetadataObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// 页面内轻提示。不返回 Future，原因同 PublishDiaryController.showHint：
  /// 等提示条关闭会把 finally 里的 loading 复位拖后约 4 秒。
  void _showHint(String message) {
    if (!_state.mounted) {
      return;
    }
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: _state.context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }
}
