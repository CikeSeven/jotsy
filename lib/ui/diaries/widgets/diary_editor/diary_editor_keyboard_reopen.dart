import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/services/app_platform.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_embed_editing.dart';
import 'diary_editor_trailing_region.dart';
import 'diary_embed_caret_input.dart';
import 'diary_embed_selectable.dart';

/// 点按正文之后，让插入点与键盘出现在该出现的地方。三种情形：
///
/// 1. 点正文最后一块下方的空白处，而最后显示的块是表格：在末尾补一个空
///    段落、插入点放进去，键盘随之弹出（[appendDiaryTrailingLine]）——表格
///    下面没有能停插入点的地方，否则接不着往下写。最后是嵌入块时不补：上游
///    把插入点停到它右侧，按情形 3 弹出键盘。手机与桌面都生效。
///
/// 2. 收起软键盘后，点回正文时重新弹出键盘。上游 AppFlowy 只在“编辑值
///    变了”时让输入法 show：编辑值是插入点所在段落的文字加偏移，
///    `NonDeltaTextInputService.attach` 发现它和上次相同就直接返回。用户用
///    系统返回手势或输入法自带的按钮收起键盘时，正文的焦点与输入连接都
///    还在，于是点回原来的插入点、或点到另一处编辑值相同的位置（最常见的
///    是从一个空行点到另一个空行：都是空文字、偏移 0）时键盘不再弹出。
///    普通输入框点按时总会 show，这里补上同样的行为：点按前后编辑值相同
///    就断开重连。编辑值变了的点按上游已按新值 show 过，不动它。键盘正
///    显示时也不动它：重新连接会让输入法重置当前面板（符号页回到字母页
///    等）。只在手机上生效；桌面没有软键盘，上游桌面选区服务每次点按本就
///    先断开再连接。
///
/// 3. 点在嵌入块旁的空白处（图片右侧、并排小图之间与右侧、块的上下留白、
///    分隔线、最后一块下方）：插入点停在块的左侧或右侧（DiaryEmbedSelectable），
///    上游却不为没有文字的块连接输入法，这里连上（[DiaryEmbedCaretInput]），
///    键盘照常弹出。点在块的内容上（[DiaryEmbedContent]：看图、播放、打开
///    卡片）不连：那是在用内容，DiaryPlaybackInteractionGuard 随后把插入点
///    还原到点之前的位置。手机与桌面都生效（桌面打字同样经输入法）。
///
/// 只观察指针（[Listener] 不参与手势竞技场，上游的点按、长按选字、拖动把手
/// 与外层滚动都不受影响）：一次点按（未越过触摸容差、未到长按时长、期间
/// 没有第二根手指）抬起后，等这一轮指针分发结束——上游在竞技场清场时才处理
/// 点按——再按上面的顺序检查。只读正文没有插入点，整个跳过。
///
/// 不是点按把插入点停到嵌入块上时（退格 / Delete 越过文字行、方向键、撤销、
/// 插入媒体），同样连上输入法：监听选区，手指都抬起、正文有焦点时连接；
/// 带“不连接输入法”标记的选区（DiaryPlaybackInteractionGuard 的还原）不连。
class DiaryEditorKeyboardReopen extends StatefulWidget {
  const DiaryEditorKeyboardReopen({
    super.key,
    required this.controller,
    required this.child,
  });

  final DiaryEditorController controller;
  final Widget child;

  @override
  State<DiaryEditorKeyboardReopen> createState() =>
      _DiaryEditorKeyboardReopenState();
}

class _DiaryEditorKeyboardReopenState extends State<DiaryEditorKeyboardReopen> {
  int? _pointer;

  /// 正文上按着的手指数（不论是不是点按）；按着时选区的变化交给点按处理。
  int _pointersDown = 0;

  /// 点按抬起后、[_afterTap] 跑完之前：上游这时才处理点按、改选区。
  bool _tapPending = false;

  late af.EditorState _state = widget.controller.state;

  @override
  void initState() {
    super.initState();
    _state.selectionNotifier.addListener(_onSelection);
  }

  @override
  void didUpdateWidget(DiaryEditorKeyboardReopen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = widget.controller.state;
    if (!identical(state, _state)) {
      if (!_state.isDisposed) {
        _state.selectionNotifier.removeListener(_onSelection);
      }
      _state = state;
      _state.selectionNotifier.addListener(_onSelection);
    }
  }

  /// 不是点按把插入点停到嵌入块上时连接输入法（见类说明）。
  void _onSelection() {
    if (_pointersDown > 0 || _tapPending || !_active) return;
    final state = _state;
    if (diaryEmbedAtCaret(state) == null) return;
    if (state.selectionExtraInfo?[af
            .selectionExtraInfoDoNotAttachTextService] ==
        true) {
      return;
    }
    // 等这次选区通知的其余监听（上游键盘服务）跑完再连。
    scheduleMicrotask(() {
      if (!mounted || !_active || diaryEmbedAtCaret(state) == null) return;
      if (!_editorFocused(state)) return;
      DiaryEmbedCaretInput.attach(state);
    });
  }

  bool _editorFocused(af.EditorState state) =>
      primaryFocus?.context
          ?.findAncestorWidgetOfExactType<af.AppFlowyEditor>()
          ?.editorState ==
      state;
  Offset _downPosition = Offset.zero;
  af.Selection? _downSelection;

  /// 按下时插入点的编辑值（见 [_editValueOf]），与点按后的比较。
  (String, int)? _downValue;

  /// 按住到长按时长即不再算点按；用计时器而非事件时间戳，测试的假时钟
  /// 与真机一致。抬起、取消、第二根手指按下与销毁时都取消。
  Timer? _tapDeadline;

  bool get _active =>
      !widget.controller.isDisposed && !widget.controller.readOnly;

  void _onDown(PointerDownEvent event) {
    _pointersDown++;
    if (_pointer != null) {
      // 双指（缩放、两指滚动）不是点按，整次手势都不算。
      _reset();
      return;
    }
    // 桌面右键是打开菜单，不是点按（触摸与手写笔按下时同为主键）。
    if (!_active || event.buttons & kPrimaryButton == 0) return;
    _pointer = event.pointer;
    _downPosition = event.position;
    _downSelection = widget.controller.state.selection;
    _downValue = _editValueOf(_downSelection);
    _tapDeadline = Timer(kLongPressTimeout, _reset);
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _downPosition).distance > kTouchSlop) _reset();
  }

  void _onUp(PointerUpEvent event) {
    _pointersDown = (_pointersDown - 1).clamp(0, 1 << 20);
    if (event.pointer != _pointer) return;
    final before = _downSelection;
    final beforeValue = _downValue;
    final position = event.position;
    _reset();
    _tapPending = true;
    scheduleMicrotask(() {
      _tapPending = false;
      _afterTap(before, beforeValue, position);
    });
  }

  void _afterTap(
    af.Selection? before,
    (String, int)? beforeValue,
    Offset position,
  ) {
    if (!mounted || !_active) return;
    if (_appendLineBelow(position)) return;
    if (_attachOnEmbed(position)) return;
    if (before == null || !before.isCollapsed || !AppPlatform.isMobile) return;
    _reopenIfUnchanged(beforeValue);
  }

  /// 折叠插入点交给输入法的编辑值：所在段落的文字与偏移（与上游
  /// `_getCurrentTextEditingValue` 对折叠选区的取法相同）。不是折叠选区或
  /// 不在文字块里时为 null。
  (String, int)? _editValueOf(af.Selection? selection) {
    if (selection == null || !selection.isCollapsed) return null;
    final delta = widget.controller.state.document
        .nodeAtPath(selection.end.path)
        ?.delta;
    if (delta == null) return null;
    return (delta.toPlainText(), selection.end.offset);
  }

  /// 情形 1：点按落在最后一个顶层块下方、需要补行时补上并弹出键盘。
  bool _appendLineBelow(Offset position) {
    final state = widget.controller.state;
    final blocks = state.document.root.children;
    if (blocks.isEmpty) return false;
    // 最后一块没有排版（滚出了虚拟列表）时点不到它下方，也量不出位置。
    final box = blocks.last.renderBox;
    if (box == null || !box.attached || !box.hasSize) return false;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if (position.dy <= bottom) return false;
    // 页尾里不属于正文的内容（阅读式编辑页的留言区等）不算正文下方的空白。
    if (DiaryEditorTrailingRegion.isHit(context, position)) return false;
    final keyboardShown = View.of(context).viewInsets.bottom > 0;
    final selection = appendDiaryTrailingLine(state);
    if (selection == null) return false;
    _showKeyboardAt(selection, keyboardShown: keyboardShown);
    return true;
  }

  /// 情形 3：点按后插入点停在嵌入块上，点的不是块的内容：连接输入法。
  bool _attachOnEmbed(Offset position) {
    final state = widget.controller.state;
    final embed = diaryEmbedAtCaret(state);
    if (embed == null) return false;
    final box = embed.renderBox;
    if (box == null || !box.attached || !box.hasSize) return false;
    // 只认落在块顶以下的点按：页头里的点按不动选区，插入点原本就在块上时
    // 不该为它抢走页头输入框的输入法。并排的小图每张只占一格，点在一排
    // 右侧的空白时上游停在最近的那张，不要求落在块的矩形里。
    if (position.dy < box.localToGlobal(Offset.zero).dy) return false;
    if (DiaryEditorTrailingRegion.isHit(context, position)) return false;
    if (DiaryEmbedContent.contains(box, position)) return false;
    return DiaryEmbedCaretInput.attach(state);
  }

  /// 情形 1 放好插入点之后：新空行的编辑值（空文字、偏移 0）可能与
  /// 输入法上次拿到的相同，上游连接时会直接返回、不弹键盘：键盘收着时同
  /// 情形 2 断开重连。
  void _showKeyboardAt(af.Selection selection, {required bool keyboardShown}) {
    if (!AppPlatform.isMobile || keyboardShown) return;
    widget.controller.state.service.keyboardService
      ?..closeKeyboard()
      ..enableKeyBoard(selection);
  }

  void _onCancel(PointerCancelEvent event) {
    _pointersDown = (_pointersDown - 1).clamp(0, 1 << 20);
    if (event.pointer == _pointer) _reset();
  }

  void _reset() {
    _tapDeadline?.cancel();
    _tapDeadline = null;
    _pointer = null;
    _downSelection = null;
    _downValue = null;
  }

  /// 情形 2。
  void _reopenIfUnchanged((String, int)? beforeValue) {
    final state = widget.controller.state;
    final selection = state.selection;
    // 图片、分隔线等非文字块上游本就不连接输入法（编辑值为 null）；编辑值
    // 变了时上游已按新值 show 过。
    final value = _editValueOf(selection);
    if (selection == null || value == null || value != beforeValue) return;
    if (View.of(context).viewInsets.bottom > 0) return;
    if (!_editorFocused(state)) return;
    final keyboard = state.service.keyboardService;
    if (keyboard == null) return;
    // 断开后同步重连：Flutter 的隐藏在微任务里检查到已有新连接，不会先
    // 收起再弹出。
    keyboard
      ..closeKeyboard()
      ..enableKeyBoard(selection);
  }

  @override
  void dispose() {
    _reset();
    if (!_state.isDisposed) {
      _state.selectionNotifier.removeListener(_onSelection);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onDown,
    onPointerMove: _onMove,
    onPointerUp: _onUp,
    onPointerCancel: _onCancel,
    child: widget.child,
  );
}
