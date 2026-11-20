// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 导图日记在编辑页里的形态（正文是一张 `mode: page` 的导图时）。
///
/// 职责边界：
/// - 识别：正文顶层第一块是 page 模式的 `mind_map`、其余都是空段落时进入
///   导图模式（[_EditDiaryMindMapFlow._syncMindMapSession]，每次构建时核对，
///   正文控制器被换掉——回填详情、续写草稿——时重建会话）；
/// - 外框：不构建文字编辑器、悬浮工具栏与录音面板，整页是导图工作区
///   （[MindMapWorkspace]），顶栏是返回、“画布 / 大纲”切换（不显示标题）、撤销 / 重做、
///   发布（新建）或保存（手动保存）与“更多”；“更多”只有导图自己的样式、导出导图与导入，
///   编辑已有日记时再加分享、编辑器设置与删除（见
///   [_EditDiaryReadingActions._mindMapDiaryMoreItems]），没有信息面板；
/// - 写回：导图的每次改动经 [_EditDiaryMindMapSession] 写进正文里那一块
///   （不进正文的撤销栈，导图有自己的撤销），正文控制器随之通知，草稿与
///   编辑的自动保存、手动保存、发布都沿用文字日记的链路；中心主题的文字
///   同步写进标题（导图日记只有一个标题）；
/// - 转换：新建页正文为空时点“思维导图”转成导图（[_convertToMindMap]，
///   画布从按钮处展开），空导图可以转回文字日记（[_convertBackToText]）。
///   两者都经 `restoreContent`，不进正文撤销栈。
class _EditDiaryMindMapSession {
  _EditDiaryMindMapSession(this.content, MindMapDocument map)
    : controller = MindMapEditingController(map);

  /// 会话绑定的正文控制器；页面换了正文控制器就要换会话。
  final editor.DiaryEditorController content;
  final MindMapEditingController controller;

  /// 把导图写回正文里的导图块。
  void write(MindMapDocument map) {
    if (content.isDisposed) return;
    final children = content.document.root.children;
    if (children.isEmpty || children.first.type != kDiaryBlockMindMap) return;
    final transaction = content.state.transaction
      ..updateNode(children.first, mindMapBlockData(map, page: true));
    content.apply(transaction, recordUndo: false, updateSelection: false);
  }

  void dispose() => controller.dispose();
}

/// 正文（AppFlowy 文档）是否为导图日记；与 `diaryMindMapPage` 同一口径。
bool _isMindMapDiaryDocument(editor.Document document) {
  final children = document.root.children;
  if (children.isEmpty) return false;
  final first = children.first;
  if (first.type != kDiaryBlockMindMap ||
      !isMindMapPageData(first.attributes)) {
    return false;
  }
  for (final rest in children.skip(1)) {
    if (rest.type != kDiaryBlockParagraph ||
        rest.children.isNotEmpty ||
        (rest.delta?.toPlainText().trim().isNotEmpty ?? false)) {
      return false;
    }
  }
  return true;
}

extension _EditDiaryMindMapFlow on _EditDiaryPageState {
  /// 按当前正文核对导图会话（构建时调用，不触发重建）。
  void _syncMindMapSession() {
    final content = _contentController;
    final isMap = _isMindMapDiaryDocument(content.document);
    final session = _mindMapSession;
    if (!isMap) {
      if (session != null) {
        _mindMapSession = null;
        session.dispose();
      }
      return;
    }
    if (session != null && identical(session.content, content)) return;
    session?.dispose();
    final first = content.document.root.children.first;
    final created = _EditDiaryMindMapSession(
      content,
      mindMapOfBlockData(first.attributes),
    );
    created.controller.onChanged = (map) {
      created.write(map);
      _syncTitleFromMindMap(map);
    };
    _mindMapSession = created;
  }

  /// 中心主题的文字就是这篇日记的标题（见 [mindMapDiaryTitle]）。
  void _syncTitleFromMindMap(MindMapDocument map) {
    final title = mindMapDiaryTitle(map);
    if (_titleController.text != title) _titleController.text = title;
  }

  /// 新建页：把空白正文换成一张导图（中心主题取已写的标题）。[origin] 为
  /// “思维导图”按钮的全局矩形，画布从这里展开。
  void _convertToMindMap(Rect? origin) {
    if (_contentController.hasContent) return;
    final title = _titleController.text
        .replaceAll(RegExp(r'\s*\n\s*'), ' ')
        .trim();
    final map = MindMapDocument.blank(text: title);
    FocusManager.instance.primaryFocus?.unfocus();
    _contentController.restoreContent(
      encodeDiaryBlocks(mindMapDiaryDocument(map)),
    );
    setState(() {
      _mindMapRevealOrigin = origin;
      _syncMindMapSession();
    });
    // 没写标题时直接编辑中心主题，键盘随之弹出。
    if (title.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final session = _mindMapSession;
        if (!mounted || session == null) return;
        session.controller.startEditing(session.controller.document.root.id);
      });
    }
  }

  /// 还只有中心主题的导图转回文字日记（中心主题的文字已经在标题里，
  /// 转回不丢东西）。
  void _convertBackToText() {
    final session = _mindMapSession;
    if (session == null || !mindMapHasOnlyRoot(session.controller.document)) {
      return;
    }
    _contentController.restoreContent('');
    setState(() {
      _mindMapRevealOrigin = null;
      _syncMindMapSession();
    });
  }

  /// 导图模式的整页。
  Widget _buildMindMapScaffold(
    BuildContext context, {
    required _ReadingFrame? reading,
  }) {
    final session = _mindMapSession!;
    final l10n = context.l10n;
    final controller = session.controller;
    final origin = _mindMapRevealOrigin;
    _mindMapRevealOrigin = null;
    final busy = _saving || _mediaImportController.isBusy;
    return MindMapPageScaffold(
      paintBackground: false,
      controller: controller,
      onBack: () => unawaited(_controller.attemptExit()),
      actions: <Widget>[
        if (!_isCreateEntry && _controller.manualEditSave)
          _buildReadingSaveButton(),
      ],
      menuTooltip: l10n.diaryEditorMoreActions,
      menuItems: <Widget>[
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.palette),
          onPressed: () => showMindMapStyleSheet(context, controller),
          child: Text(l10n.mindMapStyleSheetTitle),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.fileExport),
          onPressed: () => showMindMapExportSheet(
            context,
            controller.document,
            outline: controller.outlineView,
          ),
          child: Text(l10n.mindMapExport),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.fileImport),
          onPressed: () => importMindMapFromFile(context, controller),
          child: Text(l10n.mindMapImport),
        ),
        if (reading != null) ..._mindMapDiaryMoreItems(reading),
      ],
      trailingActions: <Widget>[
        if (_isCreateEntry)
          FloatingIslandPill(
            label: l10n.autoT0136,
            onPressed: busy ? null : _controller.openPublishPage,
          ),
      ],
      body: (BuildContext context, double topInset) => MindMapReveal(
        origin: origin,
        child: MindMapAiScope(
          allowed: _controller._aiAllowed,
          child: MindMapWorkspace(
            controller: controller,
            topInset: topInset,
            onConvertBack: _isCreateEntry ? _convertBackToText : null,
          ),
        ),
      ),
    );
  }
}
