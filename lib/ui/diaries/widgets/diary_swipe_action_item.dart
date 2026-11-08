import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import 'diary_swipe_action_background.dart';
import 'swipe_action_spec.dart';

export 'swipe_action_spec.dart';

/// 列表卡片的滑动动作：卡片跟手平移，下面露出与卡片同圆角的动作背景
/// （[DiarySwipeActionBackground]）。两个方向：
/// - 行尾动作（必有；日记归档 / 取消归档、草稿删除、待办删除）：卡片从行尾
///   往行首滑开（LTR 为左滑），背景与图标在行尾一侧，即 [icon] /
///   [actionColor] / [actionIconColor] / [onSwiped]；
/// - 行首动作（可选的 [startAction]，如待办完成）：卡片从行首往行尾滑开
///   （LTR 为右滑），背景与图标在行首一侧。没传时往这个方向拖卡片停在原位，
///   组件的结构、行为与像素和只有行尾动作时完全一样（不多一层背景）。
///
/// 两侧完全镜像：同一个阈值、只认松手位置、同样的纵向漂移判定、武装反馈与
/// 滑出收起。同一次拖动可以越过原位换到另一侧，背景随之换成那一侧的动作，
/// 松手只按最终位置判定。方向跟随 [Directionality]：RTL 时整体镜像（行首在
/// 右侧，行首动作变成左滑）。
///
/// 输入：[enabled] 为 false 时两个方向都不响应（选择模式），结构保持不变，
/// 进入/退出选择模式不会重建卡片子树；生效一侧的回调在卡片滑出并收起后
/// 调用，宿主须在这一帧把条目移出列表（之后本组件一直保持收起）。
/// 副作用：拖动进入可触发状态的瞬间发出一次轻触觉（换侧后在新一侧再震一次）。
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
/// leaving（越过阈值松手，卡片朝生效一侧滑出，不再响应手势）→ collapsing
/// （卡片移出树，生效一侧的背景随条目高度压扁）→ 回调 [onSwiped] 或
/// [startAction] 的 `onSwiped`。减少动画时滑出与收起瞬间完成。
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
    this.startAction,
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

  /// 滑开后露出的行尾动作背景表面，供回归测试定位。
  static const Key backgroundKey = ValueKey<String>('diary_swipe_background');

  /// 行首动作（[startAction]）的背景表面，供回归测试定位。
  static const Key startBackgroundKey = ValueKey<String>(
    'diary_swipe_start_background',
  );

  final String diaryId;
  final bool enabled;

  /// 行尾动作（LTR 左滑）的图标、动作色与回调。
  final FaIconData icon;
  final Color actionColor;
  final Color actionIconColor;
  final double borderRadius;
  final VoidCallback onSwiped;

  /// 行首动作（LTR 右滑），为 null 时往这个方向拖不响应。
  final SwipeActionSpec? startAction;
  final Widget child;

  @override
  State<DiarySwipeActionItem> createState() => _DiarySwipeActionItemState();
}

enum _SwipePhase { idle, leaving, collapsing }

class _DiarySwipeActionItemState extends State<DiarySwipeActionItem>
    with TickerProviderStateMixin {
  /// 卡片滑开的比例（-1~1，占条目宽度）：正值朝行首滑开（行尾动作），负值
  /// 朝行尾滑开（行首动作，只在有 [DiarySwipeActionItem.startAction] 时出现）。
  /// 拖动时直接赋值跟手，松手后补间。下界是 -1，初值必须显式给 0。
  late final AnimationController _slide = AnimationController(
    vsync: this,
    lowerBound: -1,
    value: 0,
  );

  /// 两侧背景各自看到的滑开比例（0~1）：卡片在另一侧时为 0，那一侧的背景
  /// 不画。没有行首动作时 [_slide] 不会为负，[_endSlide] 与它逐值相同。
  late final Animation<double> _endSlide = _slide.drive(
    Animatable<double>.fromCallback((double value) => math.max(value, 0.0)),
  );
  late final Animation<double> _startSlide = _slide.drive(
    Animatable<double>.fromCallback((double value) => math.max(-value, 0.0)),
  );

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

  /// 武装过渡（[_armController]）当前属于哪一侧：1 行尾动作、-1 行首动作，
  /// 与 [_slide] 的符号一致。两侧共用一个武装控制器，同一时刻只有一侧可能
  /// 武装；拖过原位换侧时直接归零——旧的一侧此时已被卡片完全盖住，归零看
  /// 不出来，不归零的话旧一侧正在回退的动作色会在新一侧阈值以前闪一下。
  double _armSide = 1;

  /// 按下的位置：判断手指总位移是横向还是纵向为主（含被识别为拖动之前的
  /// 那一小段）。
  Offset? _downPosition;

  /// 收起前条目的尺寸：收起时卡片已移出树，底板按它压扁。
  Size? _collapseFrom;

  /// 朝行首一侧生效时记下的行首动作（朝行尾一侧生效或还没生效时为 null）：
  /// 滑出与收起途中宿主撤掉了 [DiarySwipeActionItem.startAction]，背景与
  /// 回调仍用这一份走完。
  SwipeActionSpec? _leavingStartAction;

  /// 行尾动作时卡片滑开的方向：从行尾往行首（LTR 向左为 -1，RTL 向右为 1）。
  /// 行首动作的方向是它的相反数。
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
      _leavingStartAction = null;
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
    } else if (widget.startAction == null &&
        oldWidget.startAction != null &&
        _phase == _SwipePhase.idle &&
        _slide.value < 0) {
      // 卡片停在行首一侧时宿主撤掉了行首动作：同样放回原位，这次拖动不再
      // 跟手（识别器还在，但 _dragging 已清，后续更新与松手都被忽略）。这样
      // 生效时卡片在负侧就一定有行首动作（见 _commit）。
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
    // 没有行首动作：只朝行尾动作的方向滑开，往回拖到原位为止，不越过另一侧。
    // 有行首动作：越过原位即换到行首一侧继续跟手。
    final lower = widget.startAction == null ? 0.0 : -1.0;
    final slide = (_slide.value + details.delta.dx * sign / width).clamp(
      lower,
      1.0,
    );
    _slide.value = slide;
    // 正好停在原位（0）时仍算上一侧：没有可武装的距离，不影响结果。
    final side = slide > 0 ? 1.0 : (slide < 0 ? -1.0 : _armSide);
    if (side != _armSide) {
      _armSide = side;
      _armed = false;
      _armController.value = 0;
    }
    final origin = _downPosition ?? details.globalPosition;
    final moved = details.globalPosition - origin;
    // 手指总位移在当前一侧动作方向上的分量：中途换过侧时，按下点到当前位置
    // 的净位移同样只算朝这一侧的部分。
    final along = (moved.dx * sign * side).clamp(0.0, double.infinity);
    final drifted = moved.dy.abs() > along * DiarySwipeActionItem.maxDriftRatio;
    _setArmed(slide.abs() >= DiarySwipeActionItem.threshold && !drifted);
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
    if (_slide.value == 0) {
      return;
    }
    _slide.animateBack(
      0,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      curve: ExpressiveMotion.effects,
    );
  }

  /// 生效：卡片滑出 → 条目收起 → 回调生效一侧的动作。动画被打断（页面销毁）
  /// 时 TickerFuture 不会完成，后续步骤与回调都不会执行。
  void _commit() {
    // 武装时已越过阈值，符号即生效的一侧。卡片只在有行首动作时才会停在负侧
    // （宿主撤掉行首动作时 didUpdateWidget 已把卡片放回、清掉武装），所以
    // 这里负侧一定拿得到行首动作。
    final startAction = _slide.value < 0 ? widget.startAction! : null;
    setState(() {
      _phase = _SwipePhase.leaving;
      _leavingStartAction = startAction;
    });
    _slide
        .animateTo(
          startAction == null ? 1 : -1,
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
            if (!mounted) {
              return;
            }
            // 与行尾动作一样优先取宿主最新的回调，撤掉了才用生效时那份。
            if (startAction == null) {
              widget.onSwiped();
            } else {
              (widget.startAction ?? startAction).onSwiped();
            }
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final sign = _actionSign;
    final background = DiarySwipeActionBackground(
      surfaceKey: DiarySwipeActionItem.backgroundKey,
      slide: _endSlide,
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
    // 行首动作的背景：卡片朝行尾滑开时露在行首一侧，图标靠行首。没有行首
    // 动作时不建这一层，子树与只有行尾动作时相同。
    final startAction = widget.startAction ?? _leavingStartAction;
    final startBackground = startAction == null
        ? null
        : DiarySwipeActionBackground(
            surfaceKey: DiarySwipeActionItem.startBackgroundKey,
            slide: _startSlide,
            collapse: _collapse,
            armColor: _armColor,
            armPop: _armPop,
            actionSign: -sign,
            threshold: DiarySwipeActionItem.threshold,
            armedIconScale: DiarySwipeActionItem.armedIconScale,
            icon: startAction.icon,
            actionColor: startAction.actionColor,
            actionIconColor: startAction.actionIconColor,
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
        // 朝行首一侧生效时 _leavingStartAction 非空，startBackground 必然已建。
        child: _leavingStartAction == null ? background : startBackground,
      );
    } else {
      // passthrough：卡片收到的约束原样交下去（瀑布流的紧约束不被放松）；
      // Clip.none：卡片投影画在条目外侧，不能被裁。行首背景插在中间：增删
      // 它时首尾两个子组件按类型对上，卡片子树不会重挂。
      content = Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(child: background),
          if (startBackground != null) Positioned.fill(child: startBackground),
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
