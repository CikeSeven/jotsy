import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 算出自身落在最近的竖向滚动视口里（上下各多算 [marginViewports] 个视口高）
/// 的那一段，按占自身高度的比例（0 为顶、1 为底）交给 [builder]。
///
/// 完整展开的长图可能有十几屏高，整张的分片同时解码要几十 MB；按可见范围只
/// 构建附近的分片（`LongImageTilesView`），滚走的分片卸载后可被 ImageCache
/// 回收。上下多留的视口让滚动或长图截屏时下一段已在解码。
///
/// - 范围在帧后计算（布局完成才知道位置），滚动时每帧最多算一次，变化超过
///   千分之一才重建；
/// - 首帧位置未知，只给顶部（0～0，顶部那一段仍会构建）；外面没有竖向滚动
///   容器时给出整段 0～1，退化为全部构建。
class LongImageScrollRange extends StatefulWidget {
  const LongImageScrollRange({
    super.key,
    required this.builder,
    this.marginViewports = 1,
  });

  final Widget Function(BuildContext context, double start, double end) builder;
  final double marginViewports;

  @override
  State<LongImageScrollRange> createState() => _LongImageScrollRangeState();
}

class _LongImageScrollRangeState extends State<LongImageScrollRange> {
  ScrollableState? _scrollable;
  ScrollPosition? _position;
  bool _scheduled = false;
  double _start = 0;
  double _end = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
    if (!identical(scrollable, _scrollable)) {
      _position?.removeListener(_scheduleUpdate);
      _scrollable = scrollable;
      _position = scrollable?.position;
      _position?.addListener(_scheduleUpdate);
      // 在滚动容器里：位置算出来之前只放顶部那一段，免得首帧把整张的分片
      // 都发去解码；没有滚动容器时全部构建。
      _start = 0;
      _end = scrollable == null ? 1 : 0;
    }
    _scheduleUpdate();
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleUpdate);
    super.dispose();
  }

  /// 滚动通知可能发生在布局中途，统一推到帧后计算再 setState。
  void _scheduleUpdate() {
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) {
        _update();
      }
    });
  }

  void _update() {
    final box = context.findRenderObject();
    final viewport = _scrollable?.context.findRenderObject();
    if (box is! RenderBox ||
        viewport is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        !viewport.hasSize ||
        box.size.height <= 0) {
      return;
    }
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final viewportHeight = viewport.size.height;
    final margin = viewportHeight * widget.marginViewports;
    final height = box.size.height;
    final start = ((-top - margin) / height).clamp(0.0, 1.0);
    final end = ((-top + viewportHeight + margin) / height).clamp(0.0, 1.0);
    if ((start - _start).abs() < 1e-3 && (end - _end).abs() < 1e-3) {
      return;
    }
    setState(() {
      _start = start;
      _end = end;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 自身尺寸可能变化（转屏、正文重排），每次构建后都校正一次。
    _scheduleUpdate();
    return widget.builder(context, _start, _end);
  }
}
