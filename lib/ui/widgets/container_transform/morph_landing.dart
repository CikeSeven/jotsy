import 'dart:async';
import 'dart:ui' as ui show Image;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

/// 整页收回（`MorphPageRoute`）的落点模型：落到哪里、何时落、落下途中每一
/// 帧容器在哪。
///
/// 职责边界：
/// - [MorphLanding]：路由返回时给出的候选落点（按优先级），返回那一刻就
///   决定，真正落到哪一个要等下层页面重新排版后按顺序找第一个看得见的；
/// - [MorphLandingSession]：一次收回的全过程（等待 → 落下 → 落定 / 取消），
///   经 [MorphLandingSession.current] 广播给落点一侧（草稿箱角标先“扣住”
///   旧份数、列表先记下让位起点、落点卡片跟着容器变形）；
/// - [MorphTarget] / [MorphGeometry]：容器的起点 / 终点与逐帧几何，路由的
///   绘制层与列表里的活卡片（`MorphLiveTarget`）共用同一份计算，同一帧两边
///   一定对得上。
///
/// 坐标一律是导航器的坐标系（路由铺满导航器、原点重合）。

/// 一个候选落点。
@immutable
sealed class MorphLanding {
  const MorphLanding(this.tag);

  /// 落点的标识：[MorphAnchorLanding] 对应 `MorphAnchor.tag`，
  /// [MorphLiveLanding] 对应 `MorphLiveTarget.tag`。
  final Object tag;
}

/// 落到一个静态的小控件上（新建按钮、草稿箱角标）：容器收成控件的形状与
/// 底色，控件自己的样子（`MorphAnchor.appearance`）在末段淡入；下层页面
/// 全程画快照。
final class MorphAnchorLanding extends MorphLanding {
  const MorphAnchorLanding(super.tag);
}

/// 落到列表里的一张活卡片上（刚发表的新日记）：下层页面实时绘制（列表要
/// 同时播放让位动画）；卡片排好后拍成一张图交给容器（卡片自己在落下途中
/// 不画），容器里页面与这张图互相渐变，落定那一帧换回卡片本身。
final class MorphLiveLanding extends MorphLanding {
  const MorphLiveLanding(super.tag);
}

/// 落点的种类（见 [MorphLanding] 的两个子类）。
enum MorphTargetKind { anchor, live }

/// 某一刻量出的落点 / 起点：位置、圆角，小控件另有底色与外观。
@immutable
class MorphTarget {
  const MorphTarget.anchor({
    required this.tag,
    required this.rect,
    required this.radius,
    required Color this.color,
    this.appearance,
  }) : kind = MorphTargetKind.anchor,
       image = null;

  const MorphTarget.live({
    required this.tag,
    required this.rect,
    required this.radius,
    this.image,
  }) : kind = MorphTargetKind.live,
       color = null,
       appearance = null;

  final MorphTargetKind kind;
  final Object tag;

  /// 导航器坐标系里的位置。
  final Rect rect;
  final double radius;

  /// 小控件的底色（不透明）：容器收到末段时就是这个颜色。
  final Color? color;

  /// 小控件自己的样子（如新建按钮的加号、角标里的数字），按 [rect] 的尺寸
  /// 布局、画在容器正中；收回末段淡入、展开起步淡出。
  final Widget? appearance;

  /// 活卡片拍下的样子（铺满 [rect]）；拍不了时为 null，容器改为把页面淡出、
  /// 露出下面的卡片。归路由所有（路由销毁时释放）。
  final ui.Image? image;
}

/// 某一帧的容器：位置尺寸、圆角，以及容器里各层的透明度。
@immutable
class MorphFrame {
  const MorphFrame({
    required this.rect,
    required this.radius,
    required this.scrimAlpha,
    required this.groupAlpha,
    required this.appearanceAlpha,
    this.imageAlpha = 0,
  });

  /// 导航器坐标系里的容器。
  final Rect rect;
  final BorderRadius radius;

  /// 下层页面上遮罩的不透明度（0–1，乘遮罩色自己的不透明度）。
  final double scrimAlpha;

  /// 容器里“底 + 页面”整体的不透明度：小控件落点在它下面垫控件的底色，
  /// 活卡片落点在它下面就是卡片。
  final double groupAlpha;

  /// 小控件外观的不透明度（只有小控件落点才有）。
  final double appearanceAlpha;

  /// 活卡片那张图的不透明度（盖在不透明的页面上，只有活卡片落点才有）。
  final double imageAlpha;

  RRect get rrect => radius.toRRect(rect);

  /// 页面（整屏布局）到容器的变换比例：按宽度等比缩放、贴顶。
  double scaleFor(Size full) => full.width <= 0 ? 1 : rect.width / full.width;
}

/// 容器的起点 / 终点与逐帧几何（见 [frame]）。
///
/// 由路由持有：推入时是点按的新建按钮；返回时换成重新量出的落点，找不到时
/// 为 null（原地缩小淡出）。改动后通知绘制层重画、重新布局外观。
class MorphGeometry extends ChangeNotifier {
  MorphGeometry(this._target);

  MorphTarget? _target;
  MorphTarget? get target => _target;

  set target(MorphTarget? value) {
    if (identical(value, _target)) return;
    _target = value;
    notifyListeners();
  }

  /// 下层页面上遮罩的最大不透明度：与卡片展开（`ContainerTransformTransition`）
  /// 相同，只把下层压下去一点。
  static const double maxScrim = 0.28;

  /// 小控件落点：页面（连同底）在这一段进度里淡出 / 淡入，下面垫着控件的
  /// 底色。容器还比较大时就开始换成控件的颜色——收到一半时已经看不清缩小
  /// 的页面了，早点换色，落点的颜色先到，形状随后到。
  static const Interval anchorGroupFade = Interval(0.1, 0.45);

  /// 小控件的外观（加号、角标数字）在这一段进度里淡入 / 淡出：容器快收成
  /// 控件大小时才出现，原尺寸画在容器正中，不随容器缩放。
  static const Interval anchorAppearanceFade = Interval(0, 0.18);

  /// 活卡片落点：容器里页面 ↔ 卡片图在这一段进度里互相渐变（页面始终不
  /// 透明，卡片图盖在上面淡入）。下沿与 [liveShapeBlend] 的下沿相同：卡片图
  /// 完全显出时容器正好是卡片的形状。
  static const Interval liveCardFade = Interval(0.12, 0.5);

  /// 活卡片落点：容器高度从“此刻宽度下的卡片比例”过渡到“整屏插值”的进度
  /// 区间（与卡片展开同一做法，卡片按宽度缩放，容器若照常插值高度会在卡片
  /// 下面拖出一截页面）。
  static const Interval liveShapeBlend = Interval(
    0.12,
    1,
    curve: Curves.easeInOut,
  );

  /// 无处可落时终点矩形相对整屏的比例与圆角：原地缩小一点并淡出。
  static const double fallbackScale = 0.9;
  static const double fallbackRadius = 28;

  /// 进度 [progress]（0 = 落点，1 = 整页）时的容器，[full] 为整页（导航器）
  /// 的尺寸，[pageRadius] 为整页时的圆角（屏幕自带的圆角）。
  MorphFrame frame(double progress, Size full, BorderRadius pageRadius) {
    final p = progress.clamp(0.0, 1.0);
    final fullRect = Offset.zero & full;
    final target = _target;
    if (target == null || target.rect.isEmpty) {
      final closed = Rect.fromCenter(
        center: fullRect.center,
        width: full.width * fallbackScale,
        height: full.height * fallbackScale,
      );
      return MorphFrame(
        rect: Rect.lerp(closed, fullRect, p)!,
        radius: BorderRadius.lerp(
          BorderRadius.circular(fallbackRadius),
          pageRadius,
          p,
        )!,
        scrimAlpha: maxScrim * p,
        groupAlpha: p,
        appearanceAlpha: 0,
      );
    }
    final closed = target.rect;
    var rect = Rect.lerp(closed, fullRect, p)!;
    if (target.kind == MorphTargetKind.live) {
      final cardShaped = rect.width * closed.height / closed.width;
      rect = Rect.fromLTWH(
        rect.left,
        rect.top,
        rect.width,
        lerpDouble(cardShaped, rect.height, liveShapeBlend.transform(p))!,
      );
    }
    final anchor = target.kind == MorphTargetKind.anchor;
    final cardFade = liveCardFade.transform(p);
    return MorphFrame(
      rect: rect,
      // 圆角与位置尺寸同一条进度：从落点的角一路长成屏幕的角。
      radius: BorderRadius.lerp(
        BorderRadius.circular(target.radius),
        pageRadius,
        p,
      )!,
      scrimAlpha: maxScrim * p,
      // 活卡片：有卡片图时页面始终不透明、卡片图盖在上面淡入；拍不了图时
      // 退而把页面淡出，露出下面的卡片。
      groupAlpha: anchor
          ? anchorGroupFade.transform(p)
          : target.image != null
          ? 1
          : cardFade,
      appearanceAlpha: anchor && target.appearance != null
          ? 1 - anchorAppearanceFade.transform(p)
          : 0,
      imageAlpha: !anchor && target.image != null ? 1 - cardFade : 0,
    );
  }
}

/// 一次收回走到哪一步。
enum MorphLandingPhase {
  /// 路由刚开始返回，进度还停在整页上（下层页面重新排版、拍快照）。落点
  /// 一侧此时做准备：角标扣住旧份数、列表记下让位起点。
  holding,

  /// 已量出落点（或确定无处可落），容器开始收回。
  landing,

  /// 落定：路由已移除，落点接手（回弹、角标数字滚动）。
  landed,

  /// 没有落到这次的候选上（找不到、原地淡出、路由被提前移除）。
  cancelled,
}

/// 一次收回（见文件头）。同一时刻最多一个，经 [current] 广播。
class MorphLandingSession {
  MorphLandingSession._({required this.candidates, required this.originRoute});

  /// 正在进行的一次收回；没有时为 null。落点一侧（角标、列表、活卡片）监听
  /// 它，再监听这一次的 [phase]。
  static final ValueNotifier<MorphLandingSession?> current =
      ValueNotifier<MorphLandingSession?>(null);

  /// 路由开始返回时调用：结束上一次（如果还在），广播这一次。
  static MorphLandingSession begin({
    required List<MorphLanding> candidates,
    required ModalRoute<Object?> originRoute,
  }) {
    current.value?._finish(landed: false);
    final session = MorphLandingSession._(
      candidates: List<MorphLanding>.unmodifiable(candidates),
      originRoute: originRoute,
    );
    current.value = session;
    return session;
  }

  /// 候选落点，按优先级。
  final List<MorphLanding> candidates;

  /// 落点所在的路由：只认这个路由里的落点（同一标签可能也在更下层的页面里）。
  final ModalRoute<Object?> originRoute;

  final ValueNotifier<MorphLandingPhase> phase =
      ValueNotifier<MorphLandingPhase>(MorphLandingPhase.holding);

  MorphLanding? _target;

  /// 真正落向的候选；还没量出、或无处可落时为 null。
  MorphLanding? get target => _target;

  /// [tag] 是否是这一次的候选之一（还没决定落到哪个时，候选都要先准备）。
  bool involves(Object tag) => candidates.any((c) => c.tag == tag);

  /// 这一次是否正落向 [tag]。
  bool targets(Object tag) => _target?.tag == tag;

  bool _takesOverTarget = false;

  /// 容器是否接管了落点的样子（活卡片已拍成图画进容器）：落下途中落点
  /// 自己不画，落定那一帧再露出来。
  bool get takesOverTarget => _takesOverTarget;

  /// 路由量出落点（[target] 为 null 表示无处可落）后调用；[takesOverTarget]
  /// 见同名 getter。
  void startLanding(MorphLanding? target, {bool takesOverTarget = false}) {
    if (phase.value != MorphLandingPhase.holding) return;
    _target = target;
    _takesOverTarget = target != null && takesOverTarget;
    phase.value = MorphLandingPhase.landing;
  }

  /// 收回结束：[landed] 为落定在 [target] 上，否则为取消。
  void finish({required bool landed}) => _finish(landed: landed);

  void _finish({required bool landed}) {
    final done =
        phase.value == MorphLandingPhase.landed ||
        phase.value == MorphLandingPhase.cancelled;
    if (done) return;
    phase.value = landed && _target != null
        ? MorphLandingPhase.landed
        : MorphLandingPhase.cancelled;
    if (identical(current.value, this)) {
      current.value = null;
    }
  }

  /// 路由销毁时调用：还没结束就取消。销毁可能发生在导航器整理路由的途中
  /// （树被锁住、不能 setState），通知推迟到微任务里。
  void finishLater() {
    scheduleMicrotask(() => _finish(landed: false));
  }
}

/// 量出 [context] 所在渲染盒在导航器坐标系里的位置（只靠布局结果，不需要
/// 这一帧画在屏上）。
///
/// [minVisibleExtent] 大于 0 时，露在导航器里的高度不到这么多（滑出屏幕、
/// 只在列表预构建区里）返回 null：收回到一条细缝里不如原地退场。
Rect? measureInNavigator(BuildContext context, {double minVisibleExtent = 0}) {
  final box = context.findRenderObject();
  final navigatorBox = Navigator.maybeOf(context)?.context.findRenderObject();
  if (box is! RenderBox ||
      navigatorBox is! RenderBox ||
      !box.attached ||
      !navigatorBox.attached ||
      !box.hasSize ||
      box.size.isEmpty) {
    return null;
  }
  final rect = MatrixUtils.transformRect(
    box.getTransformTo(navigatorBox),
    Offset.zero & box.size,
  );
  final visible = rect.intersect(Offset.zero & navigatorBox.size);
  if (visible.isEmpty ||
      (minVisibleExtent > 0 &&
          visible.height < minVisibleExtent.clamp(0, rect.height).toDouble())) {
    return null;
  }
  return rect;
}
