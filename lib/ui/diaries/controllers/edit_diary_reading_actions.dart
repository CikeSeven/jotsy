// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 阅读式编辑页（编辑已有日记）的动作：打开 / 卸载信息面板、“更多”菜单、
/// 分享、导出与删除。版式（页头、页尾、顶栏、整页样式）见
/// `edit_diary_reading_flow.dart`。
///
/// 副作用都先补存（[_EditDiaryReadingActions._flushAndReload]），再按库里
/// 的最新内容执行；删除确认后移进回收站，以 true 结束编辑页，入口给撤销。
/// 手动保存时这些地方都不写库（`settleEditAutoSave` 只等进行中的保存），
/// 分享、导出与 AI 回应用的是上次保存的版本，离开本页的日记本胶囊同返回
/// 一样先问（见 `EditDiaryPersistenceFlow`）。
///
/// 别处的修改：编辑页之上还能打开别的页面（标签搜索、提到这篇的日记、
/// 看图……），从那里可能又打开这一篇并改掉它，而本页手里是改之前的内存
/// 副本，回来接着写会把那次修改整份覆盖。所以本页被盖住时立即补存，回到
/// 最上层时先等自己的写入落盘，再看库里这一篇：已删除就提示并退出（继续
/// 写会经 `updateDiary` 把它从回收站带回来），更新时间或标签与本页知道的
/// 不同就换成库里的最新内容并提示——手动保存且有未保存的修改时不换，
/// 留着用户的修改（保存时以本页为准），免得悄悄丢掉没存的内容。
extension _EditDiaryReadingActions on _EditDiaryPageState {
  /// 打开信息面板：挂上面板，下一帧展开（面板挂上后控制器才连上）。
  void _openMetaPanel() {
    if (_saving) return;
    // 信息面板挂着期间工具栏（段落操作栏）让位：先退出段落选择模式。
    _contentController.blockSelection.exit(DiaryBlockSelectionExit.release);
    FocusManager.instance.primaryFocus?.unfocus();
    if (_metaPanelOpen) {
      unawaited(_editPanelController.expand());
      return;
    }
    setState(() {
      _metaPanelOpen = true;
      _metaPanelRaised = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _metaPanelOpen) unawaited(_editPanelController.expand());
    });
  }

  /// 面板进度回到 0（收回到底）时卸载面板。刚挂上、还没升起时进度也是 0，
  /// 所以要先升起过（越过返回键的展开阈值）才算收回。
  void _onMetaPanelProgress(double progress) {
    if (!_metaPanelOpen) return;
    if (progress > 0.06) {
      _metaPanelRaised = true;
      return;
    }
    if (_metaPanelRaised && progress <= 0.001) {
      setState(() {
        _metaPanelOpen = false;
        _metaPanelRaised = false;
      });
    }
  }

  /// 滚到页尾的留言区（信息栏的“N 条留言”；打开日记时直接编辑时还有
  /// “更多 → 写留言”）：[end] 为 true
  /// 时让留言区末尾进入视口，否则留言区开头对齐视口顶部（同预览页）。
  ///
  /// 页尾在编辑器的虚拟列表里，滚出视口时没有构建、按 key 找不到：先按
  /// 列表下标把页尾滚出来（[DiaryEditorScrollHandle.revealFooter]），下一帧
  /// 再按留言区对齐。
  Future<void> _revealReadingComments({bool end = false}) async {
    if (_readingCommentsKey.currentContext == null) {
      await _readingScroll.revealFooter();
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    await DiaryCommentsSection.reveal(context, _readingCommentsKey, end: end);
  }

  /// 信息栏的标签胶囊：与预览页一样按这个标签打开搜索（压在编辑页之上，
  /// 返回后接着编辑）。先补存：搜索结果里就是刚写下的内容（手动保存时不
  /// 写，搜索的是上次保存的版本）。
  Future<void> _openReadingTag(int tagId) async {
    if (_saving) return;
    final saved = await _controller.settleEditAutoSave();
    if (!saved || !mounted) return;
    await openDiaryTagSearch(context, tagId);
  }

  /// 信息栏的日记本胶囊：与预览页一样回到首页、打开那本。这会直接关掉首页
  /// 之上的所有页面（编辑页的返回补存不会执行），所以先按返回的口径处理
  /// 保存（补存；手动保存且有未保存的修改时先问），保存失败或取消时留在
  /// 本页。
  Future<void> _openReadingNotebook(NotebookView notebook) async {
    if (_saving) return;
    final leave = await _controller._settleBeforeLeaving();
    if (!leave || !mounted) return;
    await openNotebookFromAnywhere(context, ref, notebook);
  }

  /// 本页是否在路由栈最上层的变化（`didChangeDependencies` 经
  /// `ModalRoute.isCurrentOf` 通知；弹出的面板、对话框同样算盖住）。
  void _onRouteCurrentChanged(bool current) {
    final was = _routeIsCurrent;
    _routeIsCurrent = current;
    if (was == null || was == current || !_isEditEntry || !_initialized) {
      return;
    }
    if (!current) {
      // 被盖住：上面的页面可能马上读这一篇，先把防抖窗口里的输入写下去
      // （手动保存时不写，包括返回时弹出的询问框盖住本页的这一下）。
      unawaited(_controller.settleEditAutoSave());
      return;
    }
    unawaited(_checkForChangesElsewhere());
  }

  /// 回到最上层后检查这一篇在别处有没有改过（见本扩展的说明）。
  ///
  /// 先 flush：等本页的写入（被盖住时的补存，或刚关掉的对话框里改的发表
  /// 时间）落盘，[_knownStoredAt] 随之更新，自己的写入不会被当成别处的修改。
  /// 标签也比对：多选批量改标签不改更新时间。日记本收录不比对——本页只在
  /// 用户改过时才写收录（`_notebookIdsDirty`），不会覆盖别处的改动。
  ///
  /// 手动保存时不写，只等进行中的保存；有未保存的修改时只看删没删，不换成
  /// 库里的内容（本页的标签与库里不同本就是没存的修改）。
  Future<void> _checkForChangesElsewhere() async {
    if (_checkingElsewhere || _saving) return;
    _checkingElsewhere = true;
    try {
      final saved = await _controller.settleEditAutoSave();
      if (!saved || !mounted) return;
      final stored = await _database.getDiaryWithTagsByDiaryId(widget.diaryId!);
      if (!mounted) return;
      final l10n = context.l10n;
      if (stored == null || stored.diary.isDeleted) {
        _controller._showHint(l10n.autoT0122);
        Navigator.of(context).pop();
        return;
      }
      if (_controller.hasUnsavedEditChanges) return;
      final storedTags = stored.tags.map((Tag tag) => tag.id).toSet();
      final changed =
          stored.diary.updatedAt != _knownStoredAt ||
          !setEquals(storedTags, _meta.value.tagIds);
      if (!changed) return;
      _reloadFromElsewhere(stored);
      _controller._showHint(l10n.diaryReadingReloaded);
    } finally {
      _checkingElsewhere = false;
    }
  }

  /// 换成库里的最新内容：与首次回填走同一条路径（[_initializeFromDetail]），
  /// 自动保存以新内容为“已存”，不会把它再写一遍。正文换了一份控制器，手机
  /// 上先收起正在编辑的焦点，免得键盘对着新正文的文首弹出来。
  void _reloadFromElsewhere(DiaryWithTags stored) {
    if (AppPlatform.isMobile && _isEditingNoteText) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() {
      _initialized = false;
      _notebookIdsDirty = false;
      _initializeFromDetail(stored, reload: true);
    });
  }

  /// 补存，再按库里的最新内容读出这一篇；保存失败或日记已不在时为 null
  /// （保存失败的提示由自动保存给出）。手动保存时不写，读出的是上次保存的
  /// 版本。
  Future<DiaryWithTags?> _flushAndReload() async {
    final saved = await _controller.settleEditAutoSave();
    if (!saved || !mounted) return null;
    return _database.getDiaryWithTagsByDiaryId(widget.diaryId!);
  }

  /// 分享（不含长图：编辑页没有可整页截取的阅读视图）。
  Future<void> _shareFromReading(DiaryPreviewResolvedStyle resolved) async {
    final detail = await _flushAndReload();
    if (detail == null || !mounted) return;
    await openDiaryPreviewShare(
      context,
      ref,
      export: _readingExport,
      detail: detail,
      background: resolved.background,
    );
  }

  /// 顶栏“更多”弹出菜单的条目（排法见 `diaryMoreMenuItems`）：编辑信息、
  /// 设为纪念日、另存为模板 | 这天的照片、AI › | 编辑器设置 | 删除。收进
  /// 日记本不单列（信息面板里就有）；页面样式不放（在预览页的“更多”里）。
  ///
  /// 分享在顶栏上；导出、写留言与 AI 回应平时在预览页（编辑页从预览页进入，
  /// 返回即是），菜单里不重复。只有“打开日记时直接编辑”开着时用户不经过
  /// 预览页，这时分享、导出与写留言排在“编辑信息”之后，AI 回应进 AI 二级
  /// 菜单（[_ReadingMenuOptions]）。
  ///
  /// 在 build 里构建（开关来自这一帧的 [_ReadingFrame.menu]，不在这里订阅）。
  /// 分享、导出、AI 回应与删除先补存，手动保存时不写（见各动作）。
  List<Widget> _readingMoreItems(_ReadingFrame frame) {
    final snapshot = frame.snapshot;
    final menu = frame.menu;
    final l10n = context.l10n;
    final diary = snapshot.detail.diary;
    final busy = _saving || _bottomPanelOpen || _mediaImportController.isBusy;
    final comments = frame.comments;
    final aiItems = _readingAiMenuItems(frame, busy: busy);
    return diaryMoreMenuItems(
      l10n,
      leading: <Widget>[
        diaryMoreMenuEntry(
          FontAwesomeIcons.circleInfo,
          l10n.diaryReadingEditInfo,
          () async {
            _openMetaPanel();
          },
        ),
      ],
      onShare: menu.openInEditor
          ? () => _shareFromReading(frame.resolved)
          : null,
      onExport: menu.openInEditor
          ? () async {
              final detail = await _flushAndReload();
              if (detail == null || !mounted) return;
              await _readingExport.exportDiary(context, ref, detail: detail);
            }
          : null,
      onWriteComment: menu.openInEditor && comments != null
          ? () async {
              // 同留言区的“写留言…”：先滚到留言区末尾再打开面板，写下的
              // 那条就在眼前。
              await _revealReadingComments(end: true);
              if (!mounted) return;
              await writeDiaryComment(context, ref, diary: diary);
            }
          : null,
      onSetAsAnniversary: menu.anniversaries
          ? () => openAnniversaryEditor(
              context,
              database: _database,
              draft: AnniversaryDraft.fromDiary(diary),
            )
          : null,
      onSaveAsTemplate: menu.templates ? _controller.saveAsTemplate : null,
      tools: <Widget>[
        if (_dayPhotos.library.isSupported && _dayPhotosDay != null)
          diaryMoreMenuEntry(
            FontAwesomeIcons.solidImages,
            l10n.diaryDayPhotosMenu,
            busy ? null : _controller.openDayPhotos,
          ),
        if (aiItems.isNotEmpty)
          ExpressiveSubmenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.wandMagicSparkles),
            menuChildren: aiItems,
            child: Text(l10n.diaryReadingAiMenu),
          ),
      ],
      settings: <Widget>[
        diaryMoreMenuEntry(
          FontAwesomeIcons.penNib,
          l10n.settingsEditorTitle,
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const EditorSettingsPage(),
            ),
          ),
        ),
      ],
      onDelete: _deleteFromReading,
    );
  }

  /// “更多 → AI ›”二级菜单的条目：写作灵感、AI 生成标题、AI 推荐标签与心情
  /// （各按 AI 模块开关出现），“打开日记时直接编辑”开着时再加 AI 回应；一项
  /// 都没有时为空，菜单里不出现“AI”这一行。
  ///
  /// 二级菜单的条目在点开时取定（见 [ExpressiveSubmenuItem]），所以停用状态
  /// 按点开那一刻：保存、导入媒体或录音 / AI 写作面板开着时写作辅助停用，AI
  /// 生成中时生成标题与推荐停用。AI 回应先补存（手动保存时不写）。
  List<Widget> _readingAiMenuItems(_ReadingFrame frame, {required bool busy}) {
    final menu = frame.menu;
    final l10n = context.l10n;
    final diaryId = frame.snapshot.detail.diary.diaryId;
    return <Widget>[
      if (menu.aiPrompts)
        diaryMoreMenuEntry(
          FontAwesomeIcons.lightbulb,
          l10n.aiSlashPrompts,
          busy ? null : _openAiPrompts,
        ),
      if (menu.aiSuggest) ...<Widget>[
        diaryMoreMenuEntry(
          FontAwesomeIcons.heading,
          l10n.aiSuggestTitle,
          busy || _aiBusy
              ? null
              : () => _controller.suggestWithAi(titleOnly: true),
        ),
        diaryMoreMenuEntry(
          FontAwesomeIcons.wandMagicSparkles,
          l10n.aiSuggestMeta,
          busy || _aiBusy
              ? null
              : () => _controller.suggestWithAi(titleOnly: false),
        ),
      ],
      if (menu.openInEditor && frame.aiReplyAvailable)
        diaryMoreMenuEntry(
          FontAwesomeIcons.commentDots,
          l10n.aiReplyMoreItem,
          () async {
            final saved = await _controller.settleEditAutoSave();
            if (!saved || !mounted) return;
            await requestAiReply(context, ref, diaryId: diaryId);
          },
        ),
    ];
  }

  /// 删除：确认后先补存（撤销删除时拿回的是改过的内容），再移进回收站，
  /// 以 true 结束编辑页，入口按“已删除”收尾并给出撤销（同预览页的删除，
  /// 不刷新“最后编辑”时间）。手动保存时没存的修改随之放弃，撤销拿回的是
  /// 上次保存的版本。
  Future<void> _deleteFromReading() async {
    final diaryId = widget.diaryId;
    if (diaryId == null || _saving) return;
    final confirmed = await confirmDiaryPreviewDelete(context);
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await _controller.settleEditAutoSave();
      if (!saved || !mounted) return;
      await _database.softDeleteDiary(diaryId, touchUpdatedAt: false);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
