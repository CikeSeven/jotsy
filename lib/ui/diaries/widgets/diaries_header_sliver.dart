import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';

/// 日记页顶栏 sliver：平时浮动（下滑隐藏、上滑即现），多选时固定在顶部。
///
/// 浮动与固定是两种不同的 sliver 渲染对象，直接切换时顶栏会凭空出现/消失，
/// 下方固定的标签栏也会随之瞬移一整个顶栏高度。这里在切换前后补一段露出过渡：
/// - 进入多选：若浮动顶栏已被滚动收起（部分或全部），先切为固定，再从此刻
///   露出的高度展开到完整显示；
/// - 退出多选：若当前滚动位置下浮动顶栏应处于收起，先保持固定、收回到该
///   露出高度，动画结束再切回浮动——两者此刻画面一致，切换没有跳变；
/// - 减少动态效果时直接切换。
///
/// 过渡只改变固定态的最小高度（可见高度），滚动范围仍是完整顶栏高度：列表
/// 内容的位置不受影响，下方固定的标签栏随可见高度同步移动。顶栏内容始终按
/// 完整高度布局、底部对齐，露出过程像从顶部滑下。
///
/// 两种形态对应不同的内部元素，切换时顶栏子树默认会整棵重建，内容里的切换
/// 动画（普通行 ↔ 多选行的交叉淡入）就来不及播放；内容挂在 GlobalKey 下，
/// 切换形态时整体迁移、保留状态。
class DiariesHeaderSliver extends StatefulWidget {
  const DiariesHeaderSliver({
    super.key,
    required this.pinned,
    required this.height,
    required this.backgroundColor,
    required this.child,
  });

  /// 是否固定在顶部（多选模式）。
  final bool pinned;
  final double height;
  final Color backgroundColor;
  final Widget child;

  @override
  State<DiariesHeaderSliver> createState() => _DiariesHeaderSliverState();
}

class _DiariesHeaderSliverState extends State<DiariesHeaderSliver>
    with SingleTickerProviderStateMixin {
  /// 实际使用的 sliver 形态；退出多选时会延后到收回动画结束再切回浮动。
  late bool _pinned = widget.pinned;

  /// 固定态的露出比例：1 = 完整显示，只在进出过渡中小于 1。
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    value: 1,
  );

  /// 最近一次布局时顶栏被滚动收起的高度（0 = 完整显示，height = 完全收起）。
  /// 由 delegate 在布局阶段写入，只在形态切换时读取，不触发重建。
  double _hiddenExtent = 0;

  final GlobalKey _contentKey = GlobalKey(debugLabel: 'diaries_header');

  @override
  void didUpdateWidget(covariant DiariesHeaderSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pinned == oldWidget.pinned) {
      return;
    }
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    final hiddenFraction = widget.height <= 0
        ? 0.0
        : (_hiddenExtent / widget.height).clamp(0.0, 1.0);
    if (widget.pinned) {
      // 浮动 → 固定：从浮动顶栏此刻露出的高度展开。
      _pinned = true;
      if (hiddenFraction <= 0 || duration == Duration.zero) {
        _reveal.value = 1;
        return;
      }
      _reveal.value = 1 - hiddenFraction;
      _reveal.animateTo(1, duration: duration, curve: ExpressiveMotion.effects);
      return;
    }
    // 固定 → 浮动：此时记录的是固定态下按滚动位置应收起的高度，也就是新建
    // 的浮动顶栏首帧所处的位置。
    if (hiddenFraction <= 0 || duration == Duration.zero) {
      _pinned = false;
      _reveal.value = 1;
      return;
    }
    _reveal
        .animateTo(
          1 - hiddenFraction,
          duration: duration,
          curve: ExpressiveMotion.exit,
        )
        .whenCompleteOrCancel(() {
          // 收回途中再次进入多选会打断动画，此时保持固定。
          if (!mounted || widget.pinned) {
            return;
          }
          setState(() {
            _pinned = false;
            _reveal.value = 1;
          });
        });
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reveal,
      builder: (BuildContext context, Widget? child) {
        return SliverPersistentHeader(
          pinned: _pinned,
          floating: !_pinned,
          delegate: _DiariesHeaderDelegate(
            height: widget.height,
            // 浮动态由 sliver 自己处理收起，最小高度保持完整高度。
            visibleHeight: _pinned ? widget.height * _reveal.value : null,
            backgroundColor: widget.backgroundColor,
            onShrinkOffset: (value) => _hiddenExtent = value,
            child: child!,
          ),
        );
      },
      child: KeyedSubtree(key: _contentKey, child: widget.child),
    );
  }
}

class _DiariesHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DiariesHeaderDelegate({
    required this.height,
    required this.visibleHeight,
    required this.backgroundColor,
    required this.onShrinkOffset,
    required this.child,
  });

  final double height;

  /// 固定态过渡中的可见高度；null 表示完整高度。
  final double? visibleHeight;
  final Color backgroundColor;

  /// 布局阶段回报被滚动收起的高度；只能记录，不能触发重建。
  final ValueChanged<double> onShrinkOffset;
  final Widget child;

  @override
  double get minExtent => visibleHeight ?? height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    onShrinkOffset(shrinkOffset);
    return ColoredBox(
      color: backgroundColor,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.bottomCenter,
          minHeight: height,
          maxHeight: height,
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DiariesHeaderDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.visibleHeight != visibleHeight ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.child != child;
  }
}
