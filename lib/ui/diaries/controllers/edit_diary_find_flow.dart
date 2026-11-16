// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 编辑页的查找与替换（#231）：顶栏“更多 → 查找和替换”或桌面的 Ctrl / ⌘ + F
/// （替换为 Ctrl + H，苹果平台 ⌘ + ⌥ + F）打开，顶栏换成 [DiaryFindBar]；查找、
/// 高亮、跳转与替换都在正文会话的 [editor.DiaryEditorController.find] 里。
///
/// 开关状态就是会话的 `find.isOpen`：正文控制器换掉时（套用模板、别处改过
/// 后重新载入）新会话的查找是关着的，查找栏随之消失，不必另外同步。
///
/// 返回键 / Esc 先关掉查找（见 `attemptExit`）。关闭时有当前匹配就把它选中
/// 交还正文，接着就能改这一处；键盘收着时不把它拉起来。
extension _EditDiaryFindFlow on _EditDiaryPageState {
  bool get _findOpen => _contentController.find.isOpen;

  /// 打开查找栏；已开着时把焦点交回查找框（[replace] 时展开替换一行、交给
  /// 替换框）。正文里选中了一段单行文字时用它作为查找文字。
  void _openFind({bool replace = false}) {
    if (_saving || _mindMapSession != null) return;
    _contentController.blockSelection.exit(DiaryBlockSelectionExit.release);
    final find = _contentController.find;
    final seed = _findSeedFromSelection();
    if (find.isOpen) {
      find.open(text: seed, replace: replace);
      final bar = _findBarKey.currentState;
      replace ? bar?.focusReplace() : bar?.focusFind();
      return;
    }
    setState(() {
      _findFocusReplace = replace;
      find.open(text: seed, replace: replace);
    });
  }

  void _closeFind() {
    final find = _contentController.find;
    if (!find.isOpen) return;
    final match = find.current;
    // 焦点还在查找栏里时按“键盘是否弹着”决定交还正文后要不要弹出键盘；
    // 查找栏卸载前先记下。
    final keyboardShown = MediaQuery.viewInsetsOf(context).bottom > 0;
    setState(find.close);
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

  /// 换掉顶栏的查找栏；[background] 为经典材质的底色（阅读式版式取预览页
  /// 样式的栏色，新建页取页面的实色栏底色）。
  PreferredSizeWidget _buildFindBar({Color? background}) => DiaryFindBar(
    key: _findBarKey,
    find: _contentController.find,
    onClose: _closeFind,
    onReplacedAll: _showReplacedAll,
    focusReplaceOnOpen: _findFocusReplace,
    background: background,
  );

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
