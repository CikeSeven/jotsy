// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 编辑页的查找与替换（#231）：顶栏“更多 → 查找和替换”或桌面的 Ctrl / ⌘ + F
/// （替换为 Ctrl + H，苹果平台 ⌘ + ⌥ + F）打开；从搜索结果直接进编辑页时
/// 带着搜索词打开（[EditDiaryPage.initialFind]）。查找、高亮、跳转与替换
/// 都在正文会话的 [editor.DiaryEditorController.find] 里。
///
/// 查找栏 [DiaryFindBar] 在键盘之上的悬浮卡片里，换下卡片里的工具栏（开着
/// 查找时键盘收起也显示）：
/// - 卡片原本就在（键盘弹着、始终显示工具栏、桌面）：卡片不动，里面的
///   工具栏与查找栏交叉淡化，高度补间（[DiaryFloatingContentSwap]）；
/// - 卡片原本不在：整张卡片升起淡入；关闭后卡片也不再显示时反向降下淡出
///   （[DiaryFloatingPresence]），播完才拿掉（[_findExitPending]）。
///
/// 开关状态就是会话的 `find.isOpen`：正文控制器换掉时（套用模板、别处改过
/// 后重新载入）新会话的查找是关着的，查找栏随之消失，不必另外同步。
///
/// 返回键 / Esc 先关掉查找（见 `attemptExit`）。关闭时有当前匹配就把它选中
/// 交还正文，接着就能改这一处；键盘收着时不把它拉起来。进入段落选择模式
/// 时查找让位（操作栏在同一张卡片里）。
extension _EditDiaryFindFlow on _EditDiaryPageState {
  bool get _findOpen => _contentController.find.isOpen;

  /// 打开查找栏；已开着时把焦点交回查找框（[replace] 时展开替换一行、交给
  /// 替换框）。正文里选中了一段单行文字时用它作为查找文字；[query] 整个
  /// 换掉查找条件、从文首找（从搜索结果进来）。[focus] 为 false 时不取
  /// 焦点、不弹键盘。
  void _openFind({
    bool replace = false,
    DiaryFindQuery? query,
    bool focus = true,
  }) {
    if (_saving || _mindMapSession != null) return;
    _contentController.blockSelection.exit(DiaryBlockSelectionExit.release);
    // 信息面板与查找卡片都贴着底边：先收起面板。
    if (_metaPanelOpen) unawaited(_editPanelController.collapse());
    final find = _contentController.find;
    final seed = query == null ? _findSeedFromSelection() : null;
    // 查找栏还挂着（已开着，或刚关上、正在收起的过渡里）时 initState 不会
    // 再来一次，焦点在这里交回去。
    final bar = _findBarKey.currentState;
    if (find.isOpen) {
      find.open(text: seed, query: query, replace: replace);
    } else {
      setState(() {
        _findFocusReplace = replace;
        _findAutofocus = focus;
        find.open(
          text: seed,
          query: query,
          replace: replace,
          fromStart: query != null,
        );
      });
    }
    if (bar != null && focus) {
      replace ? bar.focusReplace() : bar.focusFind();
    }
  }

  /// 从搜索结果进来：带着搜索词打开查找、跳到第一处，不弹键盘。正文里没有
  /// 匹配（命中的是标题、标签或留言）时不打开。
  void _openInitialFind(DiaryFindQuery query) {
    if (!mounted || _findOpen) return;
    _openFind(query: query, focus: false);
    final find = _contentController.find;
    if (find.isOpen && find.matches.isEmpty) setState(find.close);
  }

  void _closeFind() {
    final find = _contentController.find;
    if (!find.isOpen) return;
    final match = find.current;
    // 焦点还在查找栏里时按“键盘是否弹着”决定交还正文后要不要弹出键盘。
    final keyboardShown = MediaQuery.viewInsetsOf(context).bottom > 0;
    setState(() {
      find.close();
      // 卡片的去留在下一次构建时才知道（取决于焦点交还正文后工具栏是否
      // 显示）：先记下，构建里工具栏会显示就直接交叉淡化回工具栏。
      _findExitPending = true;
    });
    if (match == null ||
        match.node.parent == null ||
        _contentController.readOnly) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    final selection = editor.Selection(
      start: editor.Position(path: match.node.path, offset: match.start),
      end: editor.Position(path: match.node.path, offset: match.end),
    );
    if (keyboardShown || AppPlatform.isDesktop) {
      _contentController.select(selection);
      _contentFocusNode.requestFocus();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      _contentController.holdingKeyboard(
        () => _contentController.select(selection),
      );
    }
  }

  /// 收起的过渡播完：卡片从树里拿掉。
  void _onFindCardHidden() {
    if (mounted && _findExitPending) setState(() => _findExitPending = false);
  }

  /// 段落选择模式要用卡片放操作栏：进入时关掉查找（不选中匹配、不动焦点）。
  void _yieldFindToBlockMode() {
    final find = _contentController.find;
    if (!find.isOpen || !_contentController.blockSelection.isActive) return;
    find.close();
    _findExitPending = false;
  }

  /// 正文里选中的一段单行文字（不超过 [_findSeedMaxLength] 个字）作为查找
  /// 文字；没有选中、跨了块或太长时为 null（沿用上次的查找文字）。
  String? _findSeedFromSelection() {
    final selection = _contentController.selection?.normalized;
    if (selection == null ||
        selection.isCollapsed ||
        !listEquals(selection.start.path, selection.end.path)) {
      return null;
    }
    final text = _contentController.document
        .nodeAtPath(selection.start.path)
        ?.delta
        ?.toPlainText();
    if (text == null || selection.end.offset > text.length) return null;
    final seed = text.substring(selection.start.offset, selection.end.offset);
    return seed.length > _findSeedMaxLength || seed.contains('\n')
        ? null
        : seed;
  }

  /// 全部替换之后的提示条：换了几处，带撤销（整次替换是一步撤销）。
  void _showReplacedAll(int count) {
    final l10n = context.l10n;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(l10n.diaryReplaceAllDone(count)),
          persist: false,
          action: SnackBarAction(
            label: l10n.commonUndo,
            onPressed: _contentController.undo,
          ),
        ),
      ),
    );
  }

  /// 悬浮卡片里的查找栏。收起的过渡里同一个实例继续显示（不重新取焦点）。
  Widget _buildFindBar() => DiaryFindBar(
    key: _findBarKey,
    find: _contentController.find,
    onClose: _closeFind,
    onReplacedAll: _showReplacedAll,
    focusReplaceOnOpen: _findFocusReplace,
    autofocus: _findAutofocus,
  );

  /// 查找开着时正文底部被盖住的高度（正文末尾留白与揭示光标、匹配时让开
  /// 的部分）：查找栏量好的高度加上与键盘的间距与光标余量；录音、AI 写作
  /// 面板在卡片下面时再加上它们。
  double _findBottomSpacer() {
    var space =
        _contentController.find.barHeight.value +
        kDiaryFindBarGap +
        _EditDiaryPageState._caretToolbarClearance;
    if (_recordingPanelOpen) {
      space +=
          _EditDiaryPageState._recordingPanelReservedSpace -
          _floatingToolbarReservedSpace;
    } else if (_aiPanelOpen) {
      space += DiaryAiWritingPanel.reservedHeight;
    }
    return space;
  }

  /// 桌面打开查找 / 替换的快捷键（替换在苹果平台为 ⌘ + ⌥ + F：⌘ + H 是系统
  /// 的“隐藏应用”）。
  Map<ShortcutActivator, VoidCallback> get _findShortcuts {
    final apple = switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };
    return <ShortcutActivator, VoidCallback>{
      primaryShortcut(LogicalKeyboardKey.keyF): _openFind,
      if (apple)
        const SingleActivator(
          LogicalKeyboardKey.keyF,
          meta: true,
          alt: true,
        ): () =>
            _openFind(replace: true)
      else
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
            _openFind(replace: true),
    };
  }
}

/// 选中的文字超过这么多个字就不带进查找框（多半不是想找它）。
const int _findSeedMaxLength = 200;
