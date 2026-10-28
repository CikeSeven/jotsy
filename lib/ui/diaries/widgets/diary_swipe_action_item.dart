import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import 'diary_swipe_action_background.dart';

/// 列表卡片左滑动作（日记归档 / 取消归档、草稿删除）：卡片跟手平移，下面露出
/// 与卡片同圆角的动作背景（[DiarySwipeActionBackground]）。
///
/// 输入：[enabled] 为 false 时不响应滑动（选择模式），结构保持不变，进入/退出
/// 选择模式不会重建卡片子树；[onSwiped] 在卡片滑出并收起后回调，宿主须在这
/// 一帧把条目移出列表（之后本组件一直保持收起）。
/// 副作用：拖动进入可触发状态的瞬间发出一次轻触觉。
///
/// 为什么不用 `Dismissible`：
/// - 只要松手时横向速度够快，它不管拖了多远都会触发；滚动列表时起手略偏
///   横向、被卡片接住的一甩就会误归档。这里只认位置：松手时必须已越过阈值
///   ——背景已切到动作色并震过一次，看得见、感觉得到才生效；
/// - 被卡片接住的其实常是一次滚动：手指总位移以纵向为主（超过
///   [maxDriftRatio]）时不进入可触发状态，越过阈值后再明显纵向偏移会退回；
/// - 它的背景按卡片外接矩形裁切，卡片圆角处露出页面底色（见背景组件注释）。
///
/// 起手竞争照旧：横向超过触摸溢出距离即由卡片接住，不另加大或要求更陡的
/// 角度——日记页在首页的左右翻页 PageView 里，卡片晚接手，横向手势就会被
/// PageView 接走变成切换 Tab，并不能让给列表的纵向滚动。
///
/// 状态：idle（可拖动；松手后回弹也在这一态，可以再次按住接着拖）→
/// leaving（越过阈值松手，卡片滑出，不再响应手势）→ collapsing（卡片移出树，
/// 背景随条目高度压扁）→ 回调 [onSwiped]。减少动画时滑出与收起瞬间完成。
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

  /// 触发阈值（卡片滑开占条目宽度的比例）。背景的“淡入区间”与武装态都以它
  /// 为准，松手时必须越过它才生效。
  static const double threshold = 0.4;

  /// 手指总位移里“纵向 / 动作方向的横向”的上限（约 35°）：超过即视为在
  /// 滚动，不进入可触发状态。
  static const double maxDriftRatio = 0.7;

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

enum _SwipePhase { idle, leaving, collapsing }

class _DiarySwipeActionItemState extends State<DiarySwipeActionItem>
    with TickerProviderStateMixin {
  /// 卡片滑开的比例（0~1，占条目宽度）：拖动时直接赋值跟手，松手后补间。
  late final AnimationController _slide = AnimationController(vsync: this);

  /// 滑出后条目收起的进度（0~1）。
  late final AnimationController _collapse = AnimationController(vsync: this);

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

  _SwipePhase _phase = _SwipePhase.idle;
  bool _dragging = false;
  bool _armed = false;

  /// 按下的位置：判断手指总位移是横向还是纵向为主（含被识别为拖动之前的
  /// 那一小段）。
  Offset? _downPosition;

  /// 收起前条目的尺寸：收起时卡片已移出树，底板按它压扁。
  Size? _collapseFrom;

  /// 卡片滑开的方向：从行尾往行首（LTR 向左为 -1，RTL 向右为 1）。
  double get _actionSign =>
      Directionality.of(context) == TextDirection.ltr ? -1 : 1;

  bool get _interactive => widget.enabled && _phase == _SwipePhase.idle;

  @override
  void didUpdateWidget(covariant DiarySwipeActionItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.diaryId != oldWidget.diaryId) {
      // 宿主按 id 给条目 key，正常不会换 id；万一复用，回到静止态。
      _dragging = false;
      _downPosition = null;
      _phase = _SwipePhase.idle;
      _collapseFrom = null;
      _slide.value = 0;
      _collapse.value = 0;
      _armed = false;
      _armController.value = 0;
    } else if (!widget.enabled &&
        oldWidget.enabled &&
        _phase == _SwipePhase.idle) {
      // 拖动中进入选择模式：识别器随之移除、收不到松手，这里把卡片放回去。
      _dragging = false;
      _downPosition = null;
      _settle();
    }
  }

  @override
  void dispose() {
    _armPop.dispose();
    _armColor.dispose();
    _armController.dispose();
    _collapse.dispose();
    _slide.dispose();
    super.dispose();
  }

  void _setArmed(bool armed) {
    if (armed == _armed) {
      return;
    }
    _armed = armed;
    // 在回调里解析时长：减少动画时颜色与缩放直接落位。
    _armController.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (armed) {
      _armController.forward();
      // 只在“进入可触发状态”时震动；拖回阈值以下不再震，避免来回拖动时连震。
      unawaited(HapticFeedback.lightImpact());
    } else {
      _armController.reverse();
    }
  }

  void _handleDragDown(DragDownDetails details) {
    _downPosition = details.globalPosition;
  }

  void _handleDragStart(DragStartDetails details) {
    _downPosition ??= details.globalPosition;
    _dragging = true;
    // 回弹途中又被按住：停在当前位置，从这里接着拖。
    _slide.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final width = context.size?.width ?? 0;
    if (!_dragging || width <= 0) {
      return;
    }
    final sign = _actionSign;
    // 只朝动作方向滑开；往回拖到原位为止，不越过另一侧。
    _slide.value = (_slide.value + details.delta.dx * sign / width).clamp(
      0.0,
      1.0,
    );
    final origin = _downPosition ?? details.globalPosition;
    final moved = details.globalPosition - origin;
    final along = (moved.dx * sign).clamp(0.0, double.infinity);
    final drifted = moved.dy.abs() > along * DiarySwipeActionItem.maxDriftRatio;
    _setArmed(_slide.value >= DiarySwipeActionItem.threshold && !drifted);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    _downPosition = null;
    // 不看松手速度：只有已经武装（越过阈值且以横向为主）才生效。
    if (_armed) {
      _commit();
    } else {
      _settle();
    }
  }

  void _handleDragCancel() {
    _downPosition = null;
    if (_dragging) {
      _dragging = false;
      _settle();
    }
  }

  /// 未生效：卡片回到原位，背景退回弱化态。
  void _settle() {
    _setArmed(false);
    if (_slide.value <= 0) {
      return;
    }
    _slide.animateBack(
      0,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      curve: ExpressiveMotion.effects,
    );
  }

  /// 生效：卡片滑出 → 条目收起 → 回调。动画被打断（页面销毁）时 TickerFuture
  /// 不会完成，后续步骤与回调都不会执行。
  void _commit() {
    setState(() => _phase = _SwipePhase.leaving);
    _slide
        .animateTo(
          1,
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          curve: ExpressiveMotion.effects,
        )
        .then((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _phase = _SwipePhase.collapsing;
            _collapseFrom = context.size;
          });
          _collapse.duration = ExpressiveMotion.duration(
            context,
            ExpressiveMotion.medium,
          );
          _collapse.forward().then((_) {
            if (mounted) {
              widget.onSwiped();
            }
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final sign = _actionSign;
    final background = DiarySwipeActionBackground(
      surfaceKey: DiarySwipeActionItem.backgroundKey,
      slide: _slide,
      collapse: _collapse,
      armColor: _armColor,
      armPop: _armPop,
      actionSign: sign,
      threshold: DiarySwipeActionItem.threshold,
      armedIconScale: DiarySwipeActionItem.armedIconScale,
      icon: widget.icon,
      actionColor: widget.actionColor,
      actionIconColor: widget.actionIconColor,
      borderRadius: widget.borderRadius,
    );
    final collapseFrom = _collapseFrom;
    final Widget content;
    if (_phase == _SwipePhase.collapsing && collapseFrom != null) {
      // 卡片已滑出视野，移出树；底板保持圆角随高度压扁（不像矩形裁切那样
      // 把下沿圆角切成直角）。
      content = AnimatedBuilder(
        animation: _collapse,
        builder: (BuildContext context, Widget? child) => SizedBox(
          width: collapseFrom.width,
          height:
              collapseFrom.height *
              (1 - ExpressiveMotion.effects.transform(_collapse.value)),
          child: child,
        ),
        child: background,
      );
    } else {
      // passthrough：卡片收到的约束原样交下去（瀑布流的紧约束不被放松）；
      // Clip.none：卡片投影画在条目外侧，不能被裁。
      content = Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(child: background),
          AnimatedBuilder(
            animation: _slide,
            builder: (BuildContext context, Widget? child) =>
                FractionalTranslation(
                  translation: Offset(sign * _slide.value, 0),
                  child: child,
                ),
            child: widget.child,
          ),
        ],
      );
    }
    final interactive = _interactive;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragDown: interactive ? _handleDragDown : null,
      onHorizontalDragStart: interactive ? _handleDragStart : null,
      onHorizontalDragUpdate: interactive ? _handleDragUpdate : null,
      onHorizontalDragEnd: interactive ? _handleDragEnd : null,
      onHorizontalDragCancel: interactive ? _handleDragCancel : null,
      child: content,
    );
  }
}
