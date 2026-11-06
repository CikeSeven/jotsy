// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 阅读式版式这一帧用到的数据：这一篇此刻的样子、解析后的整页样式、信息栏
/// 的日记本胶囊，以及页尾的留言区、提到这篇的日记与 AI 回应。在 State 的
/// build 里一次算好（内部 `ref.watch`，不在 LayoutBuilder 的回调里订阅），
/// 页头、页尾与顶栏共用。
typedef _ReadingFrame = ({
  DiaryReadingSnapshot snapshot,
  DiaryPreviewResolvedStyle resolved,
  List<NotebookView> notebooks,
  DiaryPreviewComments? comments,
  DiaryPreviewBacklinks? backlinks,
  String? aiRepliesFor,
  ValueChanged<AiResultRow>? onAiContinueChat,
  bool aiReplyAvailable,
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
    );
  }

  /// 详情回填：记下原日记（id、归档、胶囊等列）与库里的正文。
  void _initReading(DiaryWithTags detail) {
    _readingBase = detail.diary;
    _readingContentJson = detail.diary.content;
    _readingContentText = detail.diary.contentText;
    _readingUpdatedAt = detail.diary.updatedAt;
  }

  /// 自动保存写库成功：页头页尾按刚写下的内容刷新（借用的首图、字数、
  /// “最后编辑于”）。只在一次写库之后重建，不随每次按键。
  void _onReadingSaved(EditDiarySnapshot snapshot) {
    if (!mounted || !_isEditEntry) return;
    setState(() {
      _readingContentJson = snapshot.contentDocJson;
      _readingContentText = snapshot.contentText;
      // 写库时 updated_at 取的就是此刻；没改正文（只改了面板）同样算编辑。
      _readingUpdatedAt = DateTime.now();
    });
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
      );

  /// 信息栏（已包好点按，点开信息面板）；这篇在当前样式下没有可显示的信息
  /// 时为 null。
  Widget? _buildReadingMeta(
    DiaryReadingSnapshot snapshot,
    DiaryPreviewResolvedStyle resolved, {
    required List<NotebookView> notebooks,
    required int commentCount,
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
    return DiaryReadingEditorHeader(
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

  /// 顶栏：外观同预览页顶栏（经典时为纸色栏，玻璃照旧），常驻不随滚动隐藏。
  /// 预览页“编辑”按钮的位置在编辑标题或正文时换成“完成”（收起键盘）。
  PreferredSizeWidget _buildReadingTopBar(
    BuildContext context, {
    required _ReadingFrame frame,
  }) {
    final snapshot = frame.snapshot;
    final resolved = frame.resolved;
    final l10n = context.l10n;
    final style = resolved.style;
    final pageColors = diaryPreviewPageColors(context, resolved);
    final editing = _titleFocusNode.hasFocus || _contentFocusNode.hasFocus;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: DiaryPreviewTopBar(
        sliver: false,
        style: style.page,
        title: switch (style.page.topBarTitle) {
          DiaryPreviewTopBarTitle.date => l10n.formatFullDate(
            snapshot.detail.diary.createdAt.toLocal(),
          ),
          DiaryPreviewTopBarTitle.none => null,
          // 编辑页不翻页，“位置”按“日记”显示（与单篇打开的预览页一致）。
          DiaryPreviewTopBarTitle.label ||
          DiaryPreviewTopBarTitle.position => l10n.autoT0120,
        },
        background: pageColors.bar,
        pageColor: pageColors.page,
        onBack: () => unawaited(_controller.attemptExit()),
        onOpenTypography: () => showDiaryTypographySheet(context),
        onEdit: () {},
        onShare: () => unawaited(_shareFromReading(resolved)),
        onMore: () => unawaited(_openReadingMore(frame)),
        editSlot: editing
            ? IconButton(
                tooltip: l10n.diaryReadingDone,
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                icon: const FaIcon(FontAwesomeIcons.check, size: 16),
              )
            : const SizedBox.shrink(),
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
