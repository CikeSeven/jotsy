import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../home/widgets/home_bar/home_top_bar_surface.dart';

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
///
/// 玻璃顶栏（[glass]）：页面不再用 SafeArea 让出状态栏，列表一直滚到状态栏
/// 下方，状态栏这一条也必须是玻璃。顶栏因此把状态栏高度 [topInset] 并进自己
/// 的范围，平时改为“浮动 + 固定”：最大高度为 topInset + [height]，最小高度为
/// topInset——下滑时收起到只剩状态栏那一条、永不滚走，上滑即现（与实色时的
/// 浮动一致）。不另加一个固定的状态栏 sliver：浮动 sliver 不理会前面固定
/// sliver 的遮挡，排在它后面时会从它下方滑过。多选时仍为固定，最小高度
/// = 最大高度。露出过渡的比例只针对可收起的 [height] 部分，状态栏那一条
/// 始终在。实色时（[glass] 为 false）完全按原来的浮动 / 固定与纯色底渲染。
class DiariesHeaderSliver extends StatefulWidget {
  const DiariesHeaderSliver({
    super.key,
    required this.pinned,
    required this.height,
    required this.backgroundColor,
    this.glass = false,
    this.topInset = 0,
    this.showHairline = false,
    required this.child,
  });

  /// 是否固定在顶部（多选模式）。
  final bool pinned;

  /// 可收起部分（顶栏内容）的高度，不含 [topInset]。
  final double height;
  final Color backgroundColor;

  /// 是否为玻璃顶栏（首页顶栏用玻璃时由页面传入）。
  final bool glass;

  /// 玻璃顶栏并进来的状态栏高度；实色时不使用。
  final double topInset;

  /// 玻璃时是否画底缘细线：只有顶栏是最下面一片玻璃时才画。
  final bool showHairline;
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

  /// 最近一次布局时顶栏可收起部分被滚动收起的高度（0 = 完整显示，height =
  /// 完全收起；玻璃时不含始终留着的状态栏那一条）。由 delegate 在布局阶段
  /// 写入，只在形态切换时读取，不触发重建。
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
    final glass = widget.glass;
    final topInset = glass ? widget.topInset : 0.0;
    return AnimatedBuilder(
      animation: _reveal,
      builder: (BuildContext context, Widget? child) {
        final double minExtent;
        if (_pinned) {
          // 固定态：过渡中按露出比例缩放可收起部分，状态栏那一条始终在。
          minExtent = topInset + widget.height * _reveal.value;
        } else {
          // 实色浮动：由 sliver 自己整体滑走，最小高度保持完整高度；
          // 玻璃浮动 + 固定：收起到只剩状态栏那一条。
          minExtent = glass ? topInset : widget.height;
        }
        return SliverPersistentHeader(
          // 玻璃时平时也要固定住状态栏那一条（浮动 + 固定）。
          pinned: _pinned || glass,
          floating: !_pinned,
          delegate: _DiariesHeaderDelegate(
            height: widget.height,
            topInset: topInset,
            minExtent: minExtent,
            glass: glass,
            showHairline: widget.showHairline,
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
    required this.topInset,
    required this.minExtent,
    required this.glass,
    required this.showHairline,
    required this.backgroundColor,
    required this.onShrinkOffset,
    required this.child,
  });

  /// 可收起部分的高度。
  final double height;

  /// 并进顶栏范围的状态栏高度（实色时为 0）。
  final double topInset;

  @override
  final double minExtent;
  final bool glass;
  final bool showHairline;
  final Color backgroundColor;

  /// 布局阶段回报可收起部分被滚动收起的高度；只能记录，不能触发重建。
  final ValueChanged<double> onShrinkOffset;
  final Widget child;

  @override
  double get maxExtent => topInset + height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // 状态栏那一条（最小高度里）不会被收起，先收起的总是可收起部分，
    // 所以夹到 height 以内就是它被收起的高度。实色时 shrinkOffset 本就
    // 不超过 height。
    onShrinkOffset(shrinkOffset.clamp(0.0, height));
    final content = ClipRect(
      child: OverflowBox(
        alignment: Alignment.bottomCenter,
        minHeight: height,
        maxHeight: height,
        child: child,
      ),
    );
    if (!glass) {
      return ColoredBox(color: backgroundColor, child: content);
    }
    // 玻璃铺满整个范围（含状态栏那一条）；内容在状态栏线以下裁切，收起
    // 途中不会清晰地压在状态栏上。与标签栏同在页面的 BackdropGroup 下，
    // 共用一次背景读取。
    return HomeTopBarSurface(
      solidColor: backgroundColor,
      showHairline: showHairline,
      grouped: true,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: content,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DiariesHeaderDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.topInset != topInset ||
        oldDelegate.minExtent != minExtent ||
        oldDelegate.glass != glass ||
        oldDelegate.showHairline != showHairline ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.child != child;
  }
}
