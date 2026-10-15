import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/app/theme/expressive_motion.dart';

/// 正文末尾为「更多」面板额外让出的空间，高度跟随 [extent]。
///
/// 悬浮工具栏叠在正文之上，正文要靠末尾留白才能把最后几行滚到工具栏上方。
/// - 展开时立即让出：随后的光标揭示（[revealDiaryCaretAbove]）需要滚动范围
///   已经足够，留白若还在慢慢长高，滚动会顶到旧的边界提前停住；
/// - 收起时随面板同速缩回：留白一次性变短会把停在末尾的正文瞬间拉下来，而面板
///   这时还在收拢，看起来像整页跳了一下；逐帧缩短时正文跟着面板平滑落下。
class DiaryToolbarPanelReserve extends StatefulWidget {
  const DiaryToolbarPanelReserve({super.key, required this.extent});

  final ValueListenable<double> extent;

  @override
  State<DiaryToolbarPanelReserve> createState() =>
      _DiaryToolbarPanelReserveState();
}

class _DiaryToolbarPanelReserveState extends State<DiaryToolbarPanelReserve>
    with SingleTickerProviderStateMixin {
  late final AnimationController _height = AnimationController.unbounded(
    vsync: this,
    value: widget.extent.value,
  );

  @override
  void initState() {
    super.initState();
    widget.extent.addListener(_handleExtentChanged);
  }

  @override
  void didUpdateWidget(covariant DiaryToolbarPanelReserve oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extent != widget.extent) {
      oldWidget.extent.removeListener(_handleExtentChanged);
      widget.extent.addListener(_handleExtentChanged);
      _height.value = widget.extent.value;
    }
  }

  @override
  void dispose() {
    widget.extent.removeListener(_handleExtentChanged);
    _height.dispose();
    super.dispose();
  }

  void _handleExtentChanged() {
    final target = widget.extent.value;
    if (target >= _height.value) {
      _height.value = target;
      return;
    }
    _height.animateTo(
      target,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.exit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _height,
      builder: (BuildContext context, Widget? child) =>
          SizedBox(height: _height.value),
    );
  }
}

/// 把正文里 [position] 处的光标滚到底部遮挡物上方。
///
/// 悬浮工具栏是叠在正文上的浮层，正文视口并不知道底部被遮住了多少：这里把
/// 光标矩形向下延长 [coveredHeight] 再交给 showOnScreen，视口只在光标确实被
/// 挡住时滚动，而且只滚到刚好露出为止；与面板展开同时长同曲线，看起来是面板
/// 把正文推了上去。编辑器尚未布局时什么也不做。
void revealDiaryCaretAbove(
  GlobalKey<quill.EditorState> editorKey, {
  required TextPosition position,
  required double coveredHeight,
  required Duration duration,
}) {
  final editor = editorKey.currentState;
  if (editor == null || !editor.mounted) {
    return;
  }
  final renderEditor = editor.renderEditor;
  if (!renderEditor.attached || !renderEditor.hasSize) {
    return;
  }
  final caret = renderEditor.getLocalRectForCaret(position);
  renderEditor.showOnScreen(
    rect: Rect.fromLTRB(
      caret.left,
      caret.top,
      caret.right,
      caret.bottom + coveredHeight,
    ),
    duration: duration,
    curve: ExpressiveMotion.effects,
  );
}
