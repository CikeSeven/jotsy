import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/diary_block_selection.dart';
import '../../controllers/diary_editor_controller.dart';
import 'diary_block_drop_targets.dart';

/// 段落选择模式里长按开始拖动整组：按下的指针 id、长按位置（全局坐标）与
/// 手指按着的那一块（落点跟着它的位移走）。
typedef DiaryBlockGroupDragStart =
    void Function(int pointer, Offset position, af.Node held);

/// 段落选择模式里块上（正文与左侧选择圈）的长按交给段落把手层，由它开始
/// 拖动选中的整组（拖动链路只有把手层一处）。由 `DiaryEditor` 持有、同时
/// 交给块包装与把手层；把手层挂载时登记 [start]。
class DiaryBlockDragRelay {
  DiaryBlockGroupDragStart? start;
}

/// 顶层块的包装（`AppFlowyEditor.blockWrapper`）：平时原样透传；段落选择
/// 模式里接管块上的点按与长按——
/// - 点按：切换手指下最内层的块（表格、收起的折叠块各算一块，见
///   [DiaryBlockSelection.toggle]）；按着 Shift 时从上次点的块连选到这里；
/// - 长按：没选中的先选上，再拖动整组（经 [relay] 交给把手层）；
/// - 块里自己处理点按的内容（看图、待办勾选、链接、折叠箭头、代码复制）
///   一律不触发（[AbsorbPointer]）；外层的滚动照常——滚动手势在祖先上，
///   点按识别器移动超过阈值就让给它。
///
/// 上游的选区手势（点按落光标、长按选词）同样会收到这次点按，它写下的选区
/// 由编辑控制器在模式里挡掉。这里的识别器比上游的更深，点按与长按都先归
/// 这里。
class DiaryBlockSelectTarget extends StatefulWidget {
  const DiaryBlockSelectTarget({
    super.key,
    required this.controller,
    required this.relay,
    required this.child,
  });

  final DiaryEditorController controller;
  final DiaryBlockDragRelay relay;
  final Widget child;

  @override
  State<DiaryBlockSelectTarget> createState() => _DiaryBlockSelectTargetState();
}

class _DiaryBlockSelectTargetState extends State<DiaryBlockSelectTarget> {
  int? _pointer;

  DiaryBlockSelection get _selection => widget.controller.blockSelection;

  af.Node? _unitAt(Offset global) {
    final hit = diaryBlockAt(widget.controller.document.root, global.dy);
    return hit == null ? null : diaryBlockSelectionUnitOf(hit);
  }

  void _tap(TapUpDetails details) {
    final unit = _unitAt(details.globalPosition);
    if (unit == null) return;
    HapticFeedback.selectionClick();
    if (HardwareKeyboard.instance.isShiftPressed) {
      _selection.selectRange(unit);
    } else {
      _selection.toggle(unit);
    }
  }

  void _longPress(LongPressStartDetails details) {
    final pointer = _pointer;
    final unit = _unitAt(details.globalPosition);
    if (pointer == null || unit == null) return;
    if (!_selection.isSelected(unit) && !_selection.isCovered(unit)) {
      _selection.toggle(unit);
    }
    widget.relay.start?.call(pointer, details.globalPosition, unit);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _selection.active,
    child: widget.child,
    builder: (BuildContext context, bool active, Widget? child) => Listener(
      onPointerDown: active ? (event) => _pointer = event.pointer : null,
      child: GestureDetector(
        behavior: active
            ? HitTestBehavior.opaque
            : HitTestBehavior.deferToChild,
        onTapUp: active ? _tap : null,
        onLongPressStart: active ? _longPress : null,
        child: AbsorbPointer(absorbing: active, child: child),
      ),
    ),
  );
}
