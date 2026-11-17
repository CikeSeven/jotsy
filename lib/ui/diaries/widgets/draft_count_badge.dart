import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../widgets/container_transform/morph_anchor.dart';
import '../../widgets/container_transform/morph_landing.dart';
import '../../widgets/rolling_text.dart';
import '../controllers/diary_create_morph.dart';

/// 首页顶栏草稿箱按钮上的份数角标：主色胶囊，数字变化时逐位滚动，出现 /
/// 消失时弹性缩放；同时是新建日记整页收回的落点（[DiaryCreateMorph.draftsBadge]）。
///
/// 外形与位置与 Material 3 的大号 `Badge` 一致（高 16、左右各 4 的内边距、
/// 贴图标右上角，见 [_BadgePlacement]），份数为 0 时不显示，超过 [maxCount]
/// 显示“99+”。
///
/// 落点时序（见 `MorphPageRoute`）：
/// 1. 新建页开始返回、落点候选里有角标时，角标“扣住”此刻显示的份数——草稿
///    补存写库后份数会先变，但整页还没落下，这时滚动只会在整页底下白白
///    播完；
/// 2. 整页收成角标的胶囊（底色同为主色，外观是扣住的数字）；
/// 3. 落定：放开扣住的份数，胶囊接住余速回弹（[MorphAnchor]），数字滚到
///    新的份数（+1）。原先是 0 份时，落下的是一颗空胶囊，“1”从下面滚进来。
/// 落到别处或取消时同样放开，按普通变化滚动。
class DraftCountBadge extends StatefulWidget {
  const DraftCountBadge({
    super.key,
    required this.count,
    required this.child,
    this.maxCount = 99,
  });

  final int count;
  final int maxCount;

  /// 角标所在的图标。
  final Widget child;

  /// 份数的显示文字：0 为空串（空胶囊），超过 [maxCount] 为“99+”。
  static String labelFor(int count, {int maxCount = 99}) {
    if (count <= 0) return '';
    return count > maxCount ? '$maxCount+' : '$count';
  }

  @override
  State<DraftCountBadge> createState() => _DraftCountBadgeState();
}

class _DraftCountBadgeState extends State<DraftCountBadge>
    with TickerProviderStateMixin {
  /// 大号角标的高度与左右内边距（与 Material 3 `Badge` 默认值相同）。
  static const double _height = 16;
  static const double _padding = 4;

  /// 此刻显示的份数（扣住期间不随 [DraftCountBadge.count] 变）。
  late int _shown = widget.count;

  /// 胶囊里此刻的文字：份数变成 0 时仍是旧数字（胶囊带着它缩走），缩没了
  /// 才清空。
  late String _label = _labelFor(widget.count);

  /// 滚动的起点文字；不在滚动时为 null。
  String? _rollFrom;

  /// 滚动方向：份数变多时新数字从下面上来。
  bool _rollUp = true;

  /// 0 = 隐藏（缩到 0），1 = 显示。无界：弹簧会越过 1。
  late final AnimationController _presence = AnimationController.unbounded(
    vsync: this,
    value: widget.count > 0 ? 1 : 0,
  )..addStatusListener(_handlePresenceStatus);

  /// 数字滚动进度（0 → 1，无界）。
  late final AnimationController _roll = AnimationController.unbounded(
    vsync: this,
    value: 1,
  )..addStatusListener(_handleRollStatus);

  ModalRoute<Object?>? _route;
  MorphLandingSession? _session;
  bool _held = false;

  @override
  void initState() {
    super.initState();
    MorphLandingSession.current.addListener(_handleSession);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(DraftCountBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_held && widget.count != _shown) {
      _animateTo(widget.count);
    }
  }

  @override
  void dispose() {
    MorphLandingSession.current.removeListener(_handleSession);
    _session?.phase.removeListener(_handlePhase);
    _presence.dispose();
    _roll.dispose();
    super.dispose();
  }

  void _handleSession() {
    final session = MorphLandingSession.current.value;
    if (session == null ||
        identical(session, _session) ||
        !session.involves(DiaryCreateMorph.draftsBadge) ||
        !identical(session.originRoute, _route)) {
      return;
    }
    _session?.phase.removeListener(_handlePhase);
    _session = session;
    session.phase.addListener(_handlePhase);
    // 扣住此刻的份数；滚动中的直接落到终点，整页收成的胶囊与它一致。
    _held = true;
    _roll.value = 1;
  }

  void _handlePhase() {
    final session = _session;
    if (session == null) return;
    final phase = session.phase.value;
    if (phase != MorphLandingPhase.landed &&
        phase != MorphLandingPhase.cancelled) {
      return;
    }
    session.phase.removeListener(_handlePhase);
    _session = null;
    _held = false;
    if (!mounted) return;
    final landedHere =
        phase == MorphLandingPhase.landed &&
        session.targets(DiaryCreateMorph.draftsBadge);
    if (widget.count != _shown) {
      _animateTo(widget.count, landing: landedHere);
    }
  }

  void _handlePresenceStatus(AnimationStatus status) {
    if (!_presence.isAnimating && _shown == 0 && _label.isNotEmpty && mounted) {
      setState(() => _label = '');
    }
  }

  void _handleRollStatus(AnimationStatus status) {
    // 起步前把进度设回 0 也会触发这里：只在停在终点时收尾。
    if (!_roll.isAnimating &&
        _roll.value == 1 &&
        _rollFrom != null &&
        mounted) {
      setState(() => _rollFrom = null);
    }
  }

  /// 从此刻显示的份数变到 [count]。[landing] 时胶囊已由整页收成：原先隐藏
  /// 的直接显示（不再弹出一次），只滚数字。
  void _animateTo(int count, {bool landing = false}) {
    final reduce = ExpressiveMotion.reduceMotion(context);
    final from = DraftCountBadge.labelFor(_shown, maxCount: widget.maxCount);
    final to = DraftCountBadge.labelFor(count, maxCount: widget.maxCount);
    final increasing = count > _shown;
    setState(() {
      // 变成 0 时胶囊带着旧数字缩走，不先把数字滚空。
      if (count > 0) {
        _rollUp = increasing;
        _rollFrom = from == to || reduce ? null : from;
        _label = to;
      } else {
        _rollFrom = null;
        if (reduce) _label = '';
      }
      _shown = count;
    });
    if (count > 0 && _rollFrom != null) {
      _roll.value = 0;
      ExpressiveMotion.springTo(
        context,
        _roll,
        1,
        spring: ExpressiveMotion.springSpatial,
        tolerance: const Tolerance(distance: 1e-3, velocity: 1e-2),
      );
    }
    final visible = count > 0 ? 1.0 : 0.0;
    if (landing && visible == 1) {
      _presence.value = 1;
    } else {
      ExpressiveMotion.springTo(
        context,
        _presence,
        visible,
        spring: visible == 1
            ? ExpressiveMotion.springSpatialFast
            : ExpressiveMotion.springSpatial,
        tolerance: const Tolerance(distance: 1e-3, velocity: 1e-2),
      );
    }
  }

  String _labelFor(int count) =>
      DraftCountBadge.labelFor(count, maxCount: widget.maxCount);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textStyle = (theme.textTheme.labelSmall ?? const TextStyle())
        .copyWith(color: scheme.onPrimary);
    final pill = DefaultTextStyle(
      style: textStyle,
      child: Container(
        height: _height,
        constraints: const BoxConstraints(minWidth: _height),
        padding: const EdgeInsets.symmetric(horizontal: _padding),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: scheme.primary,
          shape: const StadiumBorder(),
        ),
        child: AnimatedBuilder(
          animation: _roll,
          builder: (BuildContext context, Widget? _) => RollingText(
            from: _rollFrom,
            to: _label,
            progress: _roll.value,
            upward: _rollUp,
            style: textStyle,
          ),
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _BadgePlacement(Directionality.of(context)),
            child: MorphAnchor(
              tag: DiaryCreateMorph.draftsBadge,
              borderRadius: _height / 2,
              color: scheme.primary,
              landingSquash: 0.24,
              // 整页收成的胶囊：底色由容器画，这里只有扣住的数字。
              appearance: Center(
                child: Text(_labelFor(_shown), style: textStyle, maxLines: 1),
              ),
              child: AnimatedBuilder(
                animation: _presence,
                child: pill,
                builder: (BuildContext context, Widget? child) {
                  final scale = _presence.value.clamp(0.0, 2.0);
                  return Visibility.maintain(
                    visible: scale > 0.001,
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 角标贴图标右上角（RTL 时左上角），位置与 Material 3 大号 `Badge` 一致：
/// 左缘距图标右缘 12（`largeSize − offset.dx`），上缘高出图标 4。
class _BadgePlacement extends SingleChildLayoutDelegate {
  const _BadgePlacement(this.textDirection);

  final TextDirection textDirection;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      textDirection == TextDirection.ltr
      ? Offset(size.width - 12, -4)
      : const Offset(-4, -4);

  @override
  bool shouldRelayout(_BadgePlacement oldDelegate) =>
      oldDelegate.textDirection != textDirection;
}
