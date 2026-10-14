import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';

/// 顶栏页码：只让当前页数字滚动切换（向后翻时新数字自下而上进入，向前翻
/// 相反），“/ 总数”保持不动；等宽数字避免切换时宽度抖动。读屏仍读整句页码。
class ImageViewerPageCounter extends StatefulWidget {
  const ImageViewerPageCounter({
    super.key,
    required this.index,
    required this.total,
    required this.style,
  });

  final int index;
  final int total;
  final TextStyle? style;

  @override
  State<ImageViewerPageCounter> createState() => _ImageViewerPageCounterState();
}

class _ImageViewerPageCounterState extends State<ImageViewerPageCounter> {
  /// 1：翻到后一页；-1：翻到前一页。决定数字滚动方向。
  int _direction = 1;

  @override
  void didUpdateWidget(covariant ImageViewerPageCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _direction = widget.index > oldWidget.index ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style?.copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final current = widget.index + 1;
    final currentKey = ValueKey<int>(current);
    return Semantics(
      label: '$current / ${widget.total}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRect(
              child: AnimatedSwitcher(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.fast,
                ),
                switchInCurve: ExpressiveMotion.effects,
                switchOutCurve: ExpressiveMotion.exit,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.center,
                  children: <Widget>[...previousChildren, ?currentChild],
                ),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // 进入的数字从翻页方向的一侧滑入；离开的数字反向滑出
                  // （它的动画从 1 倒放到 0，所以起点取反方向）。
                  final incoming = child.key == currentKey;
                  final from = 0.6 * (incoming ? _direction : -_direction);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, from),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text('$current', key: currentKey, style: style),
              ),
            ),
            Text(' / ${widget.total}', style: style),
          ],
        ),
      ),
    );
  }
}
