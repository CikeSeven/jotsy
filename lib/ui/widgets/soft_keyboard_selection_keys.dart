// 弃用 API 只收在本文件：RawKeyboard 是框架里唯一还带着 Android 原始
// metaState / deviceId 的入口（见类注释）。清理条件：flutter/flutter#185849
// 修复并升级到含修复的 Flutter 后，删除本文件与它在编辑页的包裹。
// ignore_for_file: deprecated_member_use

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 让软键盘“选择”模式下的方向键扩展选区，而不是只移动光标。
///
/// 为什么需要：Gboard 等输入法的编辑面板打开“选择”后，方向键 / Home / End
/// 以带 `META_SHIFT_ON` 的按键发出，却不另发 Shift 按下事件。Flutter 3.47 的
/// Android 引擎（flutter/flutter#185292）对软键盘（deviceId 为
/// `KeyCharacterMap.VIRTUAL_KEYBOARD`）不再按 meta 合成 Shift，框架于是把它当成
/// 普通方向键：文本快捷键匹配到“移动光标”并报告已处理，引擎原本会读 Shift
/// 状态去扩选的兜底也就不再执行（上游回归 flutter/flutter#185849）。
///
/// 做法：被动监听 [RawKeyboard]，它在每条原生按键消息派发到焦点树之前收到
/// 同一次按键的原始 Android 数据。某次按键来自软键盘、meta 带 Shift，而
/// [HardwareKeyboard] 认为 Shift 没按下时，按框架 Android 文本快捷键表里
/// “Shift + 该键”的 Intent 交给当前焦点（标题 TextField；块正文走原生选区命令）执行。
///
/// - 输入：子树内获得焦点的可编辑文本收到的按键。
/// - 输出：命中并执行时返回 handled，按键不再落到“移动光标”的快捷键；其余一律
///   ignored，交回常规处理。
/// - 副作用：只经焦点控件自己的 Action 改选区，不改文本；实体键盘的 Shift 有
///   真实按下事件，[HardwareKeyboard] 已能看到，不经这里。
class SoftKeyboardSelectionKeys extends StatefulWidget {
  const SoftKeyboardSelectionKeys({
    super.key,
    required this.child,
    this.onExtendSelection,
  });

  final Widget child;

  /// 原生块编辑器不使用 EditableText 的 Action；返回 true 表示已经按块选区
  /// 处理。只在当前焦点属于该编辑器时返回 true，标题输入框继续走系统 Action。
  final bool Function(LogicalKeyboardKey)? onExtendSelection;

  @override
  State<SoftKeyboardSelectionKeys> createState() =>
      _SoftKeyboardSelectionKeysState();
}

class _SoftKeyboardSelectionKeysState extends State<SoftKeyboardSelectionKeys> {
  /// Android `KeyCharacterMap.VIRTUAL_KEYBOARD`：输入法经 InputConnection 发出的按键。
  static const int _virtualKeyboardDeviceId = -1;

  /// 带这些修饰键时对应的是别的快捷键（按词、到文首等），不在这里补。
  static const int _otherModifiers =
      RawKeyEventDataAndroid.modifierAlt |
      RawKeyEventDataAndroid.modifierControl |
      RawKeyEventDataAndroid.modifierMeta;

  /// 与框架 `DefaultTextEditingShortcuts` 的 Android 表里“Shift + 键”一致。
  /// LogicalKeyboardKey 覆写了 ==，不能作 const Map 的键。
  static final Map<LogicalKeyboardKey, Intent> _extendIntents =
      <LogicalKeyboardKey, Intent>{
        LogicalKeyboardKey.arrowLeft: const ExtendSelectionByCharacterIntent(
          forward: false,
          collapseSelection: false,
        ),
        LogicalKeyboardKey.arrowRight: const ExtendSelectionByCharacterIntent(
          forward: true,
          collapseSelection: false,
        ),
        LogicalKeyboardKey.arrowUp:
            const ExtendSelectionVerticallyToAdjacentLineIntent(
              forward: false,
              collapseSelection: false,
            ),
        LogicalKeyboardKey.arrowDown:
            const ExtendSelectionVerticallyToAdjacentLineIntent(
              forward: true,
              collapseSelection: false,
            ),
        LogicalKeyboardKey.home: const ExtendSelectionToLineBreakIntent(
          forward: false,
          collapseSelection: false,
          continuesAtWrap: true,
        ),
        LogicalKeyboardKey.end: const ExtendSelectionToLineBreakIntent(
          forward: true,
          collapseSelection: false,
          continuesAtWrap: true,
        ),
      };

  RawKeyEvent? _lastRawEvent;

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(_recordRawEvent);
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyKey);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_recordRawEvent);
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyKey);
    super.dispose();
  }

  // 每条原生按键消息先经过 RawKeyboard 再派发到焦点树，所以处理 [KeyEvent]
  // 时这里存的正是同一次按键的原始数据。
  void _recordRawEvent(RawKeyEvent event) => _lastRawEvent = event;

  bool _isSoftKeyboardShift(KeyEvent event) {
    final raw = _lastRawEvent;
    final data = raw?.data;
    if (raw is! RawKeyDownEvent || data is! RawKeyEventDataAndroid) {
      return false;
    }
    return data.deviceId == _virtualKeyboardDeviceId &&
        raw.logicalKey == event.logicalKey &&
        (data.metaState & RawKeyEventDataAndroid.modifierShift) != 0 &&
        (data.metaState & _otherModifiers) == 0;
  }

  KeyEventResult _handleEarlyKey(KeyEvent event) {
    if (!mounted ||
        event is KeyUpEvent ||
        HardwareKeyboard.instance.isShiftPressed ||
        !_isSoftKeyboardShift(event)) {
      return KeyEventResult.ignored;
    }
    return widget.onExtendSelection?.call(event.logicalKey) == true
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final intent = _extendIntents[event.logicalKey];
    // 框架已经看到 Shift（实体键盘，或引擎修复之后）时交回常规快捷键，
    // 否则一次按键会扩选两格。
    if (intent == null ||
        HardwareKeyboard.instance.isShiftPressed ||
        !_isSoftKeyboardShift(event)) {
      return KeyEventResult.ignored;
    }
    // 与 ShortcutManager 相同：从当前焦点向上找 Action，焦点控件自己的实现
    // （EditableText）负责按字符、按行或到行首尾扩选。
    final focusContext = primaryFocus?.context;
    if (focusContext == null) {
      return KeyEventResult.ignored;
    }
    final action = Actions.maybeFind<Intent>(focusContext, intent: intent);
    if (action == null) {
      return KeyEventResult.ignored;
    }
    final (bool enabled, Object? result) = Actions.of(
      focusContext,
    ).invokeActionIfEnabled(action, intent, focusContext);
    return enabled
        ? action.toKeyEventResult(intent, result)
        : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
