// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 阅读式版式这一帧用到的数据：这一篇此刻的样子、解析后的整页样式、信息栏
/// 的日记本胶囊，页尾的留言区、提到这篇的日记与 AI 回应，以及顶栏“更多”
/// 菜单要看的开关（[_ReadingMenuOptions]）。在 State 的 build 里一次算好
/// （内部 `ref.watch`，不在 LayoutBuilder / Builder 的回调里订阅），页头、页尾
/// 与顶栏共用。
typedef _ReadingFrame = ({
  DiaryReadingSnapshot snapshot,
  DiaryPreviewResolvedStyle resolved,
  List<NotebookView> notebooks,
  DiaryPreviewComments? comments,
  DiaryPreviewBacklinks? backlinks,
  String? aiRepliesFor,
  ValueChanged<AiResultRow>? onAiContinueChat,
  bool aiReplyAvailable,
  _ReadingMenuOptions menu,
});

/// 顶栏“更多”菜单的开关：功能管理（纪念日、日记模板）、AI 模块（写作灵感、
/// 生成标题与推荐信息），以及用户是否不经过预览页（[skipsPreview]：“打开
/// 日记时直接编辑”开着），这时分享、导出、写留言与 AI 回应留在菜单里。
/// 导图日记的“更多”另有一份（`_mindMapDiaryMoreItems`），不看这些开关。
typedef _ReadingMenuOptions = ({
  bool skipsPreview,
  bool anniversaries,
  bool templates,
  bool aiPrompts,
  bool aiSuggest,
});

/// 编辑已有日记时的“阅读式”版式：页面长得和预览页一样（纸色与配色基调、
/// 头图、标题样式、信息栏、边距与正文宽度、页尾），标题与正文就地可改。
/// 打开信息面板、“更多”、分享导出与删除见 `edit_diary_reading_actions.dart`。
///
/// 输入：详情回填时的原日记、面板草稿（[_EditDiaryPageState._meta]）、标题
/// 与自动保存写下的正文；预览页样式（`diaryPreviewStyleProvider`）。输出：
/// 页头 / 页尾 / 顶栏组件与整页主题。不写库（写库都在动作与自动保存里）。
///
/// 状态与时机：
/// - 信息栏、配色基调读面板草稿的当前值，面板里一改就变（[_onMetaChanged]
///   在阅读版式下重建页面）；
/// - 头图借用的正文首图、字数与“最后编辑于”按自动保存的节拍更新
///   （[_onReadingSaved]），不在每次按键时重新扫描正文；
/// - 信息面板平时不挂载：点信息栏（或“更多 → 编辑信息”）才挂上并展开，
///   收回到底后卸载（[_EditDiaryReadingActions._onMetaPanelProgress]），
///   页面上不留收起栏。
extension _EditDiaryReadingFlow on _EditDiaryPageState {
  /// 这一帧的阅读式版式数据；新建模式或详情还没回填时为 null（经典版式）。
  _ReadingFrame? _readingFrame(BuildContext context) {
    final base = _readingBase;
    if (!_isEditEntry || base == null) return null;
    final snapshot = _readingSnapshot(
      base,
      ref.watch(tagListProvider).value ?? const <Tag>[],
    );
    final diary = snapshot.detail.diary;
    return (
      snapshot: snapshot,
      resolved: _resolveReadingStyle(context, snapshot),
      notebooks: _readingNotebooks(),
      comments: _readingComments(context, diary),
      backlinks: DiaryPreviewExtras.backlinks(ref, diary),
      aiRepliesFor: DiaryPreviewExtras.aiRepliesFor(ref, diary),
      onAiContinueChat: DiaryPreviewExtras.aiContinueChat(context, ref),
      aiReplyAvailable: DiaryPreviewExtras.aiReplyAvailable(ref, diary),
      menu: _readingMenuOptions(),
    );
  }

  /// 顶栏“更多”菜单要看的开关（见 [_ReadingMenuOptions]）。
  _ReadingMenuOptions _readingMenuOptions() {
    final features = ref.watch(appFeaturesProvider);
    return (
      skipsPreview: ref.watch(
        diaryPreviewBehaviorProvider.select((b) => b.openInEditor),
      ),
      anniversaries: features.anniversariesEnabled,
      templates: features.templates,
      aiPrompts: ref.watch(aiModuleAvailableProvider(AiModule.prompts)),
      aiSuggest: ref.watch(aiModuleAvailableProvider(AiModule.suggest)),
    );
  }

  /// 详情回填：记下原日记（id、归档、胶囊等列）与库里的正文。
  void _initReading(DiaryWithTags detail) {
    _readingBase = detail.diary;
    _readingContentJson = detail.diary.content;
    _readingContentText = detail.diary.contentText;
    _readingUpdatedAt = detail.diary.updatedAt;
  }

  /// 详情回填与每次自动保存写库后，库里这一版的更新时间；回到前台时库里的
  /// 值与它不同，说明别处改过（见 `_checkForChangesElsewhere`）。
  DateTime? get _knownStoredAt => _readingUpdatedAt;

  /// 自动保存写库成功：页头页尾按刚写下的内容刷新（借用的首图、字数、
  /// “最后编辑于”）。只在一次写库之后重建，不随每次按键。[storedAt] 为库里
  /// 存下的更新时间（没改正文、只改了面板同样算编辑）。页面已卸载时（返回
  /// 时的补存在路由退场后才写完）只记下时间。
  void _onReadingSaved(EditDiarySnapshot snapshot, DateTime storedAt) {
    if (!_isEditEntry) return;
    void apply() {
      _readingContentJson = snapshot.contentDocJson;
      _readingContentText = snapshot.contentText;
      _readingUpdatedAt = storedAt;
    }

    if (!mounted) {
      apply();
      return;
    }
    setState(apply);
  }

  /// 这一篇此刻的样子（见 [DiaryReadingSnapshotBuilder]）。
  DiaryReadingSnapshot _readingSnapshot(Diary base, List<Tag> allTags) {
    return _readingSnapshots.build(
      base: base,
      title: _titleController.text,
      contentJson: _readingContentJson,
      contentText: _readingContentText,
      meta: _meta.value,
      createdAt: _draftPublishAt ?? base.createdAt,
      updatedAt: _readingUpdatedAt ?? base.updatedAt,
      allTags: allTags,
    );
  }

  /// 按预览页样式与这篇的心情 / 首个标签解析整页样式（与预览页同一口径）。
  DiaryPreviewResolvedStyle _resolveReadingStyle(
    BuildContext context,
    DiaryReadingSnapshot snapshot,
  ) {
    final detail = snapshot.detail;
    return DiaryPreviewResolvedStyle.resolve(
      style: ref.watch(diaryPreviewStyleProvider),
      appTheme: Theme.of(context),
      appSeed: ref.watch(appThemeSeedColorProvider),
      screenSize: MediaQuery.sizeOf(context),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      moodPalette: ref.watch(diaryMoodPaletteProvider),
      moodEmoji: snapshot.viewData.moodEmoji,
      firstTagColor: detail.tags.isEmpty ? null : detail.tags.first.color,
    );
  }

  /// 这篇所在的普通日记本（面板草稿里选中的，按书架顺序）：信息栏胶囊。
  /// 日记本功能关闭时为空。
  List<NotebookView> _readingNotebooks() {
    if (!ref.watch(appFeaturesProvider.select((f) => f.notebooks))) {
      return const <NotebookView>[];
    }
    final ids = _meta.value.notebookIds;
    if (ids.isEmpty) return const <NotebookView>[];
    final all = ref.watch(notebooksProvider).value ?? const <NotebookView>[];
    return <NotebookView>[
      for (final notebook in all)
        if (ids.contains(notebook.id)) notebook,
    ];
  }

  /// 留言区（与预览页同一口径）；“写留言…”经留言流程写入。
  DiaryPreviewComments? _readingComments(BuildContext context, Diary diary) =>
      DiaryPreviewExtras.comments(
        context,
        ref,
        diary: diary,
        sectionKey: _readingCommentsKey,
        onWrite: () => unawaited(writeDiaryComment(context, ref, diary: diary)),
        fromEditor: true,
      );

  /// 信息栏（已包好点按，点开信息面板）；这篇在当前样式下没有可显示的信息
  /// 时为 null。里面的胶囊与预览页一样各自响应：“N 条留言”滚到页尾的留言区
  /// （[canRevealComments] 为 false 时不可点），标签打开这个标签的搜索，日记本
  /// 回到首页打开那本（后两者先补存，见 `edit_diary_reading_actions.dart`）。
  Widget? _buildReadingMeta(
    DiaryReadingSnapshot snapshot,
    DiaryPreviewResolvedStyle resolved, {
    required List<NotebookView> notebooks,
    required int commentCount,
    required bool canRevealComments,
  }) {
    final style = resolved.style.meta;
    if (!DiaryPreviewMeta.hasContent(
      snapshot.detail,
      snapshot.viewData,
      style,
      notebooks: notebooks,
      commentCount: commentCount,
    )) {
      return null;
    }
    return DiaryReadingMetaButton(
      onPressed: _saving ? null : _openMetaPanel,
      child: DiaryPreviewMeta(
        detail: snapshot.detail,
        viewData: snapshot.viewData,
        style: style,
        notebooks: notebooks,
        commentCount: commentCount,
        onOpenComments: canRevealComments
            ? () => unawaited(_revealReadingComments())
            : null,
        onOpenTag: (int tagId) => unawaited(_openReadingTag(tagId)),
        // 日记本功能关闭时胶囊本就不出现（notebooks 为空）。
        onOpenNotebook: (NotebookView notebook) =>
            unawaited(_openReadingNotebook(notebook)),
      ),
    );
  }

  /// 标题输入框：文字样式与对齐同预览页标题（[diaryPreviewTitleTextStyle]），
  /// 没有下划线与填充，长标题折行；回车不换行。
  Widget _buildReadingTitleField(
    BuildContext context, {
    required DiaryPreviewResolvedStyle resolved,
    required DiaryTextAppearance appearance,
    required bool contentLocked,
  }) {
    _titleController.panguSpacing = appearance.typography.panguSpacing;
    final style = diaryPreviewTitleTextStyle(context, resolved, appearance);
    final hintColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return TextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      enabled: !contentLocked,
      readOnly: contentLocked,
      maxLength: 200,
      buildCounter:
          (
            BuildContext context, {
            required int currentLength,
            required bool isFocused,
            int? maxLength,
          }) => null,
      // 折行显示长标题（与预览页一样），但标题仍是一行文字：键盘给“完成”
      // 而不是换行，粘贴进来的换行被去掉。
      maxLines: null,
      keyboardType: TextInputType.text,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.singleLineFormatter,
      ],
      textAlign:
          diaryPreviewTitleAlign(resolved.style.title) ?? TextAlign.start,
      style: style,
      decoration: InputDecoration(
        suffixIcon: _AiTitleButton(
          visible:
              !contentLocked &&
              ref.watch(aiModuleAvailableProvider(AiModule.suggest)) &&
              ref.watch(aiPreferencesProvider.select((p) => p.titleButton)),
          busy: _aiBusy,
          title: _titleController,
          content: _contentController,
          onPressed: () =>
              unawaited(_controller.suggestWithAi(titleOnly: true)),
        ),
        suffixIconConstraints: const BoxConstraints(),
        filled: false,
        isDense: true,
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintText: context.l10n.autoT0106,
        hintStyle: style?.copyWith(color: hintColor),
      ),
      contextMenuBuilder: appTextContextMenuBuilder,
    );
  }

  /// 页头：头图、信息栏、标题与分隔线（见 [DiaryReadingEditorHeader]）。
  Widget _buildReadingHeader(
    BuildContext context, {
    required DiaryReadingSnapshot snapshot,
    required DiaryPreviewResolvedStyle resolved,
    required DiaryTextAppearance appearance,
    required bool contentLocked,
    required Widget? meta,
  }) {
    final style = resolved.style;
    final diary = snapshot.detail.diary;
    final viewData = snapshot.viewData;
    final coverSource = switch (style.cover.mode) {
      DiaryPreviewCoverMode.hidden => null,
      _ when style.cover.useFirstImage => viewData.coverSource,
      _ => normalizeOptionalText(diary.cover),
    };
    // 头图通栏贴顶时只让出状态栏，浮岛压在头图上；其余情况再让出浮岛那一
    // 行，标题与卡片式头图不被岛盖住（与预览页相同）。
    final bannerOnTop =
        coverSource != null &&
        style.cover.mode == DiaryPreviewCoverMode.banner &&
        !resolved.coverInColumn;
    final header = DiaryReadingEditorHeader(
      resolved: resolved,
      cover: coverSource == null
          ? null
          : DiaryReadingCover(
              source: coverSource,
              resolved: resolved,
              heroTag: diaryCoverHeroTag(diary.diaryId),
              placeholder: widget.coverHero?.placeholder,
              onTap: (ImageViewerHero? hero) => openDiaryPreviewImages(
                context,
                sources: viewData.images,
                initialSource: coverSource,
                hero: hero,
              ),
            ),
      meta: style.meta.position == DiaryPreviewMetaPosition.end ? null : meta,
      title: _buildReadingTitleField(
        context,
        resolved: resolved,
        appearance: appearance,
        contentLocked: contentLocked,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(
        top:
            MediaQuery.viewPaddingOf(context).top +
            diaryPreviewIslandClearance(bannerOnTop: bannerOnTop),
      ),
      // 锚点包住整个页头：它的下缘滚进浮岛那一行后标题胶囊浮出。
      child: KeyedSubtree(key: _readingTitleAnchor, child: header),
    );
  }

  /// 页尾（正文之后、底部占位之前）：信息栏在正文之后时的信息栏、“最后
  /// 编辑于”、提到这篇的日记、留言区与 AI 回应，与预览页同一组件与间距。
  /// 整段是 [DiaryEditorTrailingRegion]：点这里不会开始编辑正文。
  Widget? _buildReadingTrailing(
    BuildContext context, {
    required _ReadingFrame frame,
    required DiaryPreviewResolvedStyle resolved,
    required Widget? meta,
  }) {
    final style = resolved.style;
    final diary = frame.snapshot.detail.diary;
    final metaAtEnd =
        meta != null && style.meta.position == DiaryPreviewMetaPosition.end;
    final children = <Widget>[
      if (metaAtEnd) ...<Widget>[const SizedBox(height: 20), meta],
      ...diaryPreviewTrailing(
        context,
        diaryId: diary.diaryId,
        resolved: resolved,
        editedLabel: style.body.showLastEdited
            ? diaryPreviewEditedLabel(
                context.l10n,
                diary,
                style.body.editedFormat,
              )
            : null,
        backlinks: frame.backlinks,
        comments: frame.comments,
        aiRepliesFor: frame.aiRepliesFor,
        onAiContinueChat: frame.onAiContinueChat,
      ),
    ];
    if (children.isEmpty) return null;
    return DiaryEditorTrailingRegion(
      child: DiaryPreviewColumn(
        resolved: resolved,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  /// 浮岛顶栏：叠在正文之上（正文与头图从岛下面滚过），常驻不随滚动隐藏。
  /// 左侧返回岛，中间按预览页样式的“顶栏标题”浮出标题胶囊，右侧动作胶囊
  /// （见 [_buildReadingIsland]）。只包住正文：信息面板、悬浮工具栏与加载
  /// 遮罩仍叠在岛的上面。
  Widget _wrapReadingIslands(
    BuildContext context, {
    required _ReadingFrame frame,
    required Widget child,
  }) {
    final resolved = frame.resolved;
    final chip = diaryPreviewTitleChip(
      context.l10n,
      diary: frame.snapshot.detail.diary,
      mode: resolved.style.page.topBarTitle,
    );
    return FloatingTopBarHost(
      contentMaxWidth: resolved.maxContentWidth,
      statusBarColor: diaryPreviewPageColors(context, resolved).bar,
      leading: FloatingBackIsland(
        onPressed: () => unawaited(_controller.attemptExit()),
      ),
      trailing: _buildReadingIsland(frame),
      title: chip?.text,
      titleSemantics: chip?.semantics,
      titleAnchor: chip != null && chip.afterScroll
          ? _readingTitleAnchor
          : null,
      titleTooltip: context.l10n.diaryPreviewBackToTop,
      onTitleTap: () => unawaited(_readingScroll.revealTop()),
      child: child,
    );
  }

  /// 右侧动作胶囊。平时是 [分享 · 更多]；编辑标题或正文时原地变形为
  /// [完成 · 更多]（“完成”收起键盘，打字时用不到分享，“更多”始终在最右侧，
  /// 与预览页一致）。手动保存时在“更多”之前一直是“保存”图标而不放“完成”：
  /// 对勾读起来像“确认 / 保存”，并排会让人以为点“完成”也会保存（键盘用系统
  /// 返回收起）。
  Widget _buildReadingIsland(_ReadingFrame frame) {
    final l10n = context.l10n;
    final editing = _titleFocusNode.hasFocus || _contentFocusNode.hasFocus;
    return FloatingActionIsland(
      children: <Widget>[
        FloatingIslandSlot(
          visible: !editing,
          child: IconButton(
            tooltip: l10n.previewShare,
            onPressed: () => unawaited(_shareFromReading(frame.resolved)),
            icon: const FaIcon(FontAwesomeIcons.shareFromSquare, size: 16),
          ),
        ),
        if (_controller.manualEditSave)
          _buildReadingSaveButton()
        else
          FloatingIslandSlot(
            visible: editing,
            child: IconButton(
              tooltip: l10n.diaryReadingDone,
              onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
              icon: const FaIcon(FontAwesomeIcons.check, size: 16),
            ),
          ),
        DiaryMoreMenuIslandButton(items: _readingMoreItems(frame)),
      ],
    );
  }

  /// 手动保存时的“保存”图标：有未保存的修改时可点（只随 `unsaved` 局部
  /// 重建，不牵动整页），没有修改与写库期间停用；保存成功后换成主色对勾
  /// 停留 1 秒（[_EditDiaryPageState._flashEditSaved]），显式着主色免得
  /// 停用的灰色读成“没保存上”。
  Widget _buildReadingSaveButton() {
    final l10n = context.l10n;
    final saved = _editSavedFlash;
    return ValueListenableBuilder<bool>(
      valueListenable: _controller._editAutoSave.unsaved,
      builder: (BuildContext context, bool unsaved, Widget? _) => IconButton(
        tooltip: saved ? l10n.diaryEditSaved : l10n.commonSave,
        onPressed: unsaved && !_saving
            ? () => unawaited(_controller.saveEditManually())
            : null,
        icon: ExpressiveIconSwap(
          switchKey: saved,
          child: saved
              ? FaIcon(
                  FontAwesomeIcons.check,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                )
              : const FaIcon(FontAwesomeIcons.floppyDisk, size: 16),
        ),
      ),
    );
  }
}

/// 阅读式版式下编辑器的左右内边距：与 [DiaryPreviewColumn] 的文字列对齐——
/// 限宽时加上正文列居中后外侧的空白，再加样式的左右边距。
double _readingGutter(DiaryPreviewResolvedStyle resolved, double width) {
  final column = resolved.maxContentWidth;
  final outside = column == null ? 0.0 : math.max(0.0, (width - column) / 2);
  return outside + resolved.horizontalPadding;
}
