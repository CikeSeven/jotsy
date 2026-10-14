import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';

/// 列表卡片左滑动作（归档 / 取消归档）：单个 [Dismissible] + 跟手反馈的背景。
///
/// 输入：[enabled] 为 false 时关闭滑动（选择模式），但 [Dismissible] 根节点保留，
/// 进入/退出选择模式不会重建卡片子树；[onSwiped] 在条目滑出并收起后回调。
/// 副作用：拖动越过触发阈值的瞬间发出一次轻触觉。
///
/// 为什么不再用静态背景：原背景是“矩形色块 + 固定图标”，拖动 1px 就整块露出，
/// 看不出松手会不会触发，圆角卡片滑开时还会露出矩形直角。现在：
/// - 背景与卡片同圆角；
/// - 未到阈值时背景是弱化色，图标随拖动距离淡入放大（直接跟手，不是补间）；
/// - 越过阈值：背景切到动作色、图标弹一下并轻震，明确“松手即生效”；拖回阈值
///   以下恢复弱化态，用户随时可以反悔。
/// 拖动进度经 [ValueNotifier] 只驱动背景重绘，卡片本体不随指针事件重建。
class DiarySwipeActionItem extends StatefulWidget {
  const DiarySwipeActionItem({
    super.key,
    required this.diaryId,
    required this.enabled,
    required this.icon,
    required this.actionColor,
    required this.actionIconColor,
    required this.borderRadius,
    required this.onSwiped,
    required this.child,
  });

  /// 触发阈值（占卡片宽度的比例），与 [Dismissible] 默认值一致，显式声明是为了
  /// 让背景的“淡入区间”和“武装态”与真正的触发点对齐。
  static const double threshold = 0.4;

  /// 越过阈值时图标的放大倍数。
  static const double armedIconScale = 1.2;

  /// 滑开后露出的背景表面，供回归测试定位。
  static const Key backgroundKey = ValueKey<String>('diary_swipe_background');

  final String diaryId;
  final bool enabled;
  final FaIconData icon;
  final Color actionColor;
  final Color actionIconColor;
  final double borderRadius;
  final VoidCallback onSwiped;
  final Widget child;

  @override
  State<DiarySwipeActionItem> createState() => _DiarySwipeActionItemState();
}

class _DiarySwipeActionItemState extends State<DiarySwipeActionItem>
    with SingleTickerProviderStateMixin {
  /// 卡片滑开的比例（0~1），由 Dismissible 每个指针事件/动画帧回报。
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  /// 武装态过渡：背景/图标颜色走 effects，图标“弹一下”走 spatial。
  late final AnimationController _armController = AnimationController(
    vsync: this,
  );
  late final CurvedAnimation _armColor = CurvedAnimation(
    parent: _armController,
    curve: ExpressiveMotion.effects,
    reverseCurve: ExpressiveMotion.exit,
  );
  late final CurvedAnimation _armPop = CurvedAnimation(
    parent: _armController,
    curve: ExpressiveMotion.spatial,
    reverseCurve: ExpressiveMotion.exit,
  );

  void _handleUpdate(DismissUpdateDetails details) {
    _progress.value = details.progress;
    if (details.reached == details.previousReached) {
      return;
    }
    // 在回调里解析时长：减少动画时颜色与缩放直接落位。
    _armController.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (details.reached) {
      _armController.forward();
      // 只在“进入可触发状态”时震动；拖回阈值以下不再震，避免来回拖动时连震。
      unawaited(HapticFeedback.lightImpact());
    } else {
      _armController.reverse();
    }
  }

  @override
  void dispose() {
    _armPop.dispose();
    _armColor.dispose();
    _armController.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = ExpressiveMotion.reduceMotion(context);
    return Dismissible(
      key: ValueKey<String>('archive_${widget.diaryId}'),
      direction: widget.enabled
          ? DismissDirection.endToStart
          : DismissDirection.none,
      dismissThresholds: const <DismissDirection, double>{
        DismissDirection.endToStart: DiarySwipeActionItem.threshold,
      },
      // 回弹/滑出与收起走 token；减少动画时回弹瞬时完成、滑出后直接移除。
      movementDuration: ExpressiveMotion.duration(
        context,
        ExpressiveMotion.fast,
      ),
      resizeDuration: reduceMotion ? null : ExpressiveMotion.standard,
      onUpdate: _handleUpdate,
      onDismissed: (_) => widget.onSwiped(),
      background: _SwipeActionBackground(
        progress: _progress,
        armColor: _armColor,
        armPop: _armPop,
        icon: widget.icon,
        actionColor: widget.actionColor,
        actionIconColor: widget.actionIconColor,
        borderRadius: widget.borderRadius,
      ),
      child: widget.child,
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.progress,
    required this.armColor,
    required this.armPop,
    required this.icon,
    required this.actionColor,
    required this.actionIconColor,
    required this.borderRadius,
  });

  final ValueListenable<double> progress;
  final Animation<double> armColor;
  final Animation<double> armPop;
  final FaIconData icon;
  final Color actionColor;
  final Color actionIconColor;
  final double borderRadius;

  /// 图标在“滑开距离 / 阈值”的这一段内由透明变为不透明：起点约等于图标开始
  /// 露出，终点在完全露出后不久，避免图标还被卡片压着时就已经是实色。
  static const Interval _iconReveal = Interval(0.15, 0.45);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[progress, armColor]),
      builder: (BuildContext context, Widget? child) {
        final armed = armColor.value;
        final reveal = (progress.value / DiarySwipeActionItem.threshold).clamp(
          0.0,
          1.0,
        );
        final iconColor = Color.lerp(
          colorScheme.onSurfaceVariant,
          actionIconColor,
          armed,
        )!;
        final scale =
            lerpDouble(0.7, 1, reveal)! *
            (1 + (DiarySwipeActionItem.armedIconScale - 1) * armPop.value);
        return DecoratedBox(
          key: DiarySwipeActionItem.backgroundKey,
          decoration: BoxDecoration(
            color: Color.lerp(
              colorScheme.surfaceContainerHighest,
              actionColor,
              armed,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.xl),
              child: Transform.scale(
                scale: scale,
                child: FaIcon(
                  icon,
                  size: 18,
                  color: iconColor.withValues(
                    alpha: iconColor.a * _iconReveal.transform(reveal),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
