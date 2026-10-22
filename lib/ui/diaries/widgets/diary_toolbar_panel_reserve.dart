import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';

/// 正文末尾为「更多」面板额外让出的空间，高度跟随 [extent]。
///
/// 悬浮工具栏叠在正文之上，正文要靠末尾留白才能把最后几行滚到工具栏上方。
/// - 展开时立即让出：随后的光标揭示（`revealDiaryEditorCaretAbove`）需要滚动范围
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
