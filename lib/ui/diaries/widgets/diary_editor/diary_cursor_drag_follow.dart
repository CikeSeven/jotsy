import 'package:appflowy_editor/appflowy_editor.dart' as af;
// 拖动方式的键与枚举未导出，判断上游正在做哪种拖动要用到；只读取固定版本
// 写进选区附加信息的值。
// ignore: implementation_imports
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_selection_service.dart'
    show MobileSelectionDragMode, selectionDragModeKey;
import 'package:flutter/widgets.dart';

/// 上游手机选区服务自己的“插入点式”拖动：Android 长按后拖着扩选（按词）、
/// iOS 长按后拖着移光标、Android 横滑移光标、拖动折叠光标的把手。
///
/// 这些拖动的选区只在手指移动时由上游重新计算。拖到正文上下边缘时
/// `DiaryEditorSelectionGestures` 自动滚动，手指不动、内容在动，这里按上游
/// 同一手势的规则替它重新取选区，选区跟着内容一路扩展；手指再动时上游接着
/// 按自己的起点计算，两边结果一致。上游在滚动时也有一份重新取选区的逻辑，
/// 但它把 Android 的长按扩选当成移光标、一滚就收成光标，且只跟它自己的
/// 自动滚动走（可编辑正文已关掉，见 `DiaryEditorController` 的 EditorState）。
///
/// 输入：开始时的选区与附加信息、之后的拖动点（全局坐标）。副作用：以
/// uiEvent 写回选区，附加信息与上游这一手势的更新相同。
class DiaryCursorDragFollow {
  DiaryCursorDragFollow._(this._state, this._anchor, {required this.words});

  /// 刚发生的选区变化若来自上游的插入点式拖动，以此时的选区为起点开始
  /// 跟随；否则为 null。
  ///
  /// Android 长按选中的词是之后扩选的固定一端（与上游的长按起点相同）：
  /// 长按开始与拖动更新都带着“不弹浮动工具栏”，以此与其他插入点式拖动区分。
  static DiaryCursorDragFollow? begin(af.EditorState state) {
    final selection = state.selection;
    final info = state.selectionExtraInfo;
    if (selection == null ||
        info?[selectionDragModeKey] != MobileSelectionDragMode.cursor) {
      return null;
    }
    return DiaryCursorDragFollow._(
      state,
      selection,
      words: info?[af.selectionExtraInfoDisableFloatingToolbar] == true,
    );
  }

  final af.EditorState _state;
  final af.Selection _anchor;

  /// 上一次选区通知时的选区，见 [interrupted]。
  late af.Selection? _seen = _anchor;

  /// 选区通知后是否该停止跟随：选区换成了别的、且不是插入点式拖动写下的
  /// （附加信息不带拖动方式）。同一选区不带拖动方式的再写一次不算——正文
  /// 获得焦点时会把原选区再写一遍（长按选字会接上输入法、拿到焦点），上游
  /// 松手时也写回原选区；手指抬起由调用方结束跟随。
  bool interrupted() {
    final selection = _state.selection;
    final changed = selection != _seen;
    _seen = selection;
    return changed &&
        _state.selectionExtraInfo?[selectionDragModeKey] !=
            MobileSelectionDragMode.cursor;
  }

  /// 按词扩选（Android 长按）；否则选区为跟着拖动点的光标。
  final bool words;

  /// 拖动点到光标中心的偏移，只用于光标式拖动：上游在长按与横滑时把光标
  /// 放在手指处（偏移约为 0），拖动折叠光标的把手时把手指位置挪到把手上方
  /// 的那一行。由调用方在上游放下光标的那次触点事件之后量一次（[measure]），
  /// 之后按手指加这段偏移取位置，自动滚动时光标不会跳行。
  Offset grab = Offset.zero;

  /// 以上游刚放下的光标与手指此刻的位置 [finger] 量出 [grab]。
  void measure(Offset finger) {
    if (words) return;
    final caret = _caretCenter(_state.selection?.end);
    if (caret != null) grab = caret - finger;
  }

  /// 按拖动点 [point]（已加 [grab]、夹进看得见的范围）重新取选区；与上游
  /// 同一手势移动到这里时的结果相同。选区没变时不写。
  void follow(Offset point) {
    final service = _state.service.selectionService;
    if (!words) {
      final position = service.getPositionInOffset(point);
      if (position == null) return;
      // 与上游移光标相同，经选区服务写回（它按当前拖动方式补上附加信息）。
      service.updateSelection(af.Selection.collapsed(position));
      return;
    }
    final word = service
        .getNodeInOffset(point)
        ?.selectable
        ?.getWordBoundaryInOffset(point);
    if (word == null) return;
    final next = diaryLongPressWordSelection(_anchor, word);
    if (next == _state.selection) return;
    _state.updateSelectionWithReason(
      next,
      reason: af.SelectionUpdateReason.uiEvent,
      extraInfo: {
        selectionDragModeKey: MobileSelectionDragMode.cursor,
        af.selectionExtraInfoDisableFloatingToolbar: true,
      },
    );
  }

  Offset? _caretCenter(af.Position? position) {
    if (position == null) return null;
    final selectable = _state.document.nodeAtPath(position.path)?.selectable;
    final local = selectable?.getCursorRectInPosition(position);
    if (selectable == null || local == null) return null;
    return selectable.transformRectToGlobal(local).center;
  }
}

/// Android 长按后拖着扩选的选区（与固定版本上游 `_onLongPressUpdateAndroid`
/// 相同）：拖动点所在的词 [word] 在长按选中的词 [anchor] 之后，就从 anchor
/// 的起点选到 word 的终点；在之前就从 anchor 的终点选到 word 的起点；与
/// anchor 重叠时只选 anchor。
@visibleForTesting
af.Selection diaryLongPressWordSelection(
  af.Selection anchor,
  af.Selection word,
) {
  final after =
      word.end.path > anchor.end.path ||
      word.end.path.equals(anchor.end.path) &&
          word.end.offset > anchor.end.offset;
  if (after) return af.Selection(start: anchor.start, end: word.end).normalized;
  final before =
      word.start.path < anchor.start.path ||
      word.start.path.equals(anchor.start.path) &&
          word.start.offset < anchor.start.offset;
  if (before) {
    return af.Selection(start: anchor.end, end: word.start).normalized;
  }
  return anchor;
}
