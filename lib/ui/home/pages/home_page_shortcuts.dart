part of 'home_page.dart';

/// 首页的键盘快捷键（所有窗口宽度都有效）：
/// - Ctrl+N（macOS / iOS 为 ⌘+N）：新建日记，与侧边栏新建按钮同一入口；
/// - Ctrl+F（⌘+F）：打开日记搜索页（由日记页注册的入口执行）；
/// - Ctrl+1…4（⌘+1…4）：切到第 n 个可见 Tab，超出可见数量时忽略。
///
/// 生效范围：快捷键挂在首页 Scaffold 外层，只有焦点在首页子树内时才收到
/// 按键。推入的页面（编辑页、搜索页、底部面板与对话框）是别的路由，焦点
/// 在它们那里，快捷键自然不响应；返回首页时路由恢复焦点，快捷键重新生效。
/// 首页内的输入框先处理按键，只有它不认识的组合才冒泡到这里；上面这些组合
/// 在输入框里都没有既定含义，不会冲突。
///
/// 焦点：`_shortcutFocusNode` 默认获得首页路由的焦点（autofocus，只在路由
/// 里还没有焦点时生效），不参与 Tab 键遍历、不进语义树，不改变任何外观。
extension _HomePageShortcuts on _HomePageState {
  Widget _wrapShortcuts(Widget child) {
    return CallbackShortcuts(
      bindings: _shortcutBindings(),
      child: Focus(
        focusNode: _shortcutFocusNode,
        autofocus: true,
        includeSemantics: false,
        child: child,
      ),
    );
  }

  static const List<LogicalKeyboardKey> _tabDigits = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
  ];

  Map<ShortcutActivator, VoidCallback> _shortcutBindings() {
    // 苹果平台的主修饰键是 ⌘，其余平台是 Ctrl。
    final apple = switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };
    SingleActivator primary(LogicalKeyboardKey key) =>
        SingleActivator(key, control: !apple, meta: apple);
    return <ShortcutActivator, VoidCallback>{
      primary(LogicalKeyboardKey.keyN): _createFromShortcut,
      primary(LogicalKeyboardKey.keyF): _searchFromShortcut,
      for (var i = 0; i < _tabDigits.length; i++)
        primary(_tabDigits[i]): () {
          unawaited(_controller.switchToIndex(i));
        },
    };
  }

  /// 按住 Ctrl+N 会连续触发：新建流程（草稿面板 / 编辑页）打开前的异步
  /// 准备期间忽略后续触发，免得叠开多个编辑页。
  void _createFromShortcut() {
    if (_shortcutCreateRunning) {
      return;
    }
    _shortcutCreateRunning = true;
    unawaited(_openCreate().whenComplete(() => _shortcutCreateRunning = false));
  }

  /// 日记页还没注册入口（首帧之前）时什么也不做。
  void _searchFromShortcut() {
    _diariesSearchAction?.call();
  }
}
