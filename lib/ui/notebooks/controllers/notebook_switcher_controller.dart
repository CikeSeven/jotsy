import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import '../viewmodels/notebook_deck_entries.dart';

/// 卡组从哪里打开、收回到哪里。
enum NotebookSwitcherOrigin {
  /// 列表栏左缘（右滑拉出的胶囊）。
  edge,

  /// 标签栏最前面的切换胶囊。
  chip,
}

/// 卡组的阶段。
enum NotebookSwitcherPhase {
  /// 看不见，浮层已隐藏。
  idle,

  /// 手指按着：右滑拉出途中，或拉开后不松手拖选。
  dragging,

  /// 已打开或正弹向打开。
  open,

  /// 选中了一项，正在抽出卡片 / 等待验证。
  selecting,

  /// 正收回来处（或选中后收进切换胶囊）。
  closing,
}

/// 面板悬浮的位置（全局 y）：右滑拉出时以武装那一刻手指的高度为中心，
/// 从切换胶囊打开时顶边贴在胶囊下方。浮层第一次见到某个锚点时据此定下
/// 面板顶边，之后面板变高只往下长、碰到底边才往上让。
@immutable
class NotebookPanelAnchor {
  const NotebookPanelAnchor.center(this.y) : top = false;
  const NotebookPanelAnchor.top(this.y) : top = true;

  final double y;

  /// [y] 是面板顶边（true）还是中心（false）。
  final bool top;
}

/// 页面给卡组的接口：几何、当前范围、验证与提交切换。
abstract interface class NotebookSwitcherHost {
  /// 页面的 context（读减少动画设置、触发触觉）。
  BuildContext get context;

  /// 列表栏（右滑手势层）的全局矩形。
  Rect? get paneRect;

  /// 切换胶囊此刻完整显示在屏幕上时的全局矩形，否则为 null。
  Rect? get chipRect;

  /// 这一项就是当前范围。
  bool isCurrent(NotebookDeckEntry entry);

  /// 进入前的验证（上锁的本子），返回是否放行；不需要验证时直接 true。
  Future<bool> authorize(NotebookDeckEntry entry);

  /// 切换到这一项（经范围控制器：退出多选、列表从行首一侧切入）。
  void commit(NotebookDeckEntry entry);
}

/// 卡组交给控制器的接口：拖选时的命中测试与边缘自动滚动、选中时的抽出。
abstract interface class NotebookDeckHandle {
  /// 全局坐标 [position] 下可以点选的那一项（没有为 null）。
  NotebookDeckEntry? entryAt(Offset position);

  /// 拖选时手指在 [position]：靠近卡组上下边缘时自动滚动；null 停止。
  void autoScroll(Offset? position);

  /// 抬起 / 放下（拖选高亮）。
  void lift(String? key);

  /// 抽出选中的一张、其余变淡；[key] 为 null 时放回。
  void pullOut(String? key);

  /// 验证没通过：被选的那张左右轻晃一下。
  void shake(String key);

  /// 收起开着的长按菜单；没有开着的菜单时返回 false。
  bool closeMenu();
}

/// 首页日记本卡组的状态机：右滑拉出 → 长成卡组 → 拖选 / 点选 → 收进切换
/// 胶囊（或收回左缘），以及从切换胶囊打开。
///
/// 输入：手势层的 [dragStart] / [dragUpdate] / [dragEnd] / [dragCancel]，
/// 浮层上收起用的 [closeDragStart]（之后同样走 update / end / cancel），
/// 页面的 [openFromChip] / [close] / [dismissImmediately]，卡组的 [select]。
/// 输出：浮层逐帧读取的 [stage]（见下）、[armPop]、[fingerY]、[origin] 等，
/// 胶囊的 [chipHidden] / [chipBounce]；副作用：触觉、经 [host] 验证与提交切换、
/// 显示 / 隐藏浮层 [portal]。
///
/// [stage] 是一根统一的进度轴（`AnimationController.unbounded`）：
/// - 0 → 1：左缘胶囊随拉动长出（只在 [NotebookSwitcherOrigin.edge]），1 时
///   武装；
/// - 1 → 2：容器从起点（左缘胶囊 / 切换胶囊）形变成面板，2 为完全打开。
/// 拖动时直接按手指距离赋值（跟手），松手后弹簧到 2（打开）、0（收回左缘）
/// 或 1（收进切换胶囊）——同一根轴上的弹簧，途中再被手指接住也是连续的。
class NotebookSwitcherController extends ChangeNotifier {
  NotebookSwitcherController({
    required TickerProvider vsync,
    required this.host,
  }) : stage = AnimationController.unbounded(vsync: vsync),
       armPop = AnimationController.unbounded(vsync: vsync),
       chipBounce = AnimationController.unbounded(vsync: vsync, value: 1);

  final NotebookSwitcherHost host;

  /// 进度轴，见类注释。
  final AnimationController stage;

  /// 武装圆底的弹出（0–1，弹簧会略越过 1 再落回）。
  final AnimationController armPop;

  /// 落进切换胶囊后胶囊的回弹缩放（静止为 1）。
  final AnimationController chipBounce;

  /// 浮层（遮罩、容器与卡组）。
  final OverlayPortalController portal = OverlayPortalController();

  /// 容器正占着切换胶囊的位置：真实胶囊不画，由容器里的副本代替。
  final ValueNotifier<bool> chipHidden = ValueNotifier<bool>(false);

  /// 拉过这么远（逻辑像素）武装：震一次，松手即打开。
  static const double armDistance = 64;

  /// 胶囊长出时的橡皮筋系数：越拉越慢，拉到 [armDistance] 时宽度到顶。
  static const double pullRubber = 48;

  /// 拉开后上下移动超过这么远进入拖选。
  static const double dragSelectSlop = 16;

  /// 往回甩到这么快（逻辑像素 / 秒）就收回，即使已经武装。
  static const double cancelFlingVelocity = 300;

  /// 胶囊长成面板这一段的默认距离范围与起手太靠右时的下限。
  static const double minSpan = 120;
  static const double maxSpan = 200;
  static const double shortestSpan = 72;

  /// 从切换胶囊打开时面板顶边与胶囊下缘的间距。
  static const double panelGap = 8;

  NotebookSwitcherPhase _phase = NotebookSwitcherPhase.idle;
  NotebookSwitcherOrigin _origin = NotebookSwitcherOrigin.edge;

  /// 收向切换胶囊时胶囊副本显示的那一项（null 为当前范围）。
  NotebookDeckEntry? _landingEntry;

  NotebookDeckHandle? _deck;

  double _pull = 0;
  double _span = 160;
  double _fingerY = 0;
  double _directionSign = 1;
  Rect? _pane;
  bool _armed = false;
  bool _dragSelecting = false;
  double? _openAnchorY;
  NotebookDeckEntry? _hovered;

  NotebookPanelAnchor? _panelAnchor;

  /// 面板悬浮的位置；右滑还没武装时为 null（只有左缘胶囊）。
  NotebookPanelAnchor? get panelAnchor => _panelAnchor;

  /// 这次拖动是在打开的卡组上往回收（[closeDragStart]），不是从列表上拉出：
  /// 不进拖选，松手按进度与甩动方向决定收回还是弹回。
  bool _reverse = false;
  double _stageTarget = 0;

  NotebookSwitcherPhase get phase => _phase;
  NotebookSwitcherOrigin get origin => _origin;

  /// 收向切换胶囊时胶囊副本显示的那一项；null 时显示当前范围。
  NotebookDeckEntry? get landingEntry => _landingEntry;

  /// 卡组是否在屏上（含拉出途中与收起途中）。
  bool get isVisible => _phase != NotebookSwitcherPhase.idle;

  /// 是否拦下系统返回（看得见就先收起）。
  bool get blocksBack => isVisible;

  /// 手指此刻的全局 y（左缘胶囊的纵向中心跟着它）。
  double get fingerY => _fingerY;

  /// 打开时列表栏的全局矩形。
  Rect? get pane => _pane;

  /// 正在拖选：横向不再控制开合。
  bool get dragSelecting => _dragSelecting;

  /// 行首方向：LTR 为 1（左缘、向右拉），RTL 为 -1。
  double get directionSign => _directionSign;

  /// 卡组组件挂上。
  void attachDeck(NotebookDeckHandle handle) => _deck = handle;

  /// 卡组组件卸下：只在登记的仍是它时清空（新卡组可能先挂上）。
  void detachDeck(NotebookDeckHandle handle) {
    if (identical(_deck, handle)) _deck = null;
  }

  bool get _reduceMotion => ExpressiveMotion.reduceMotion(host.context);

  // ==================== 右滑手势 ====================

  /// 手势层接手一次右滑。正在收回左缘时被接住，从此刻的进度接着拉。
  void dragStart(Offset position, {required TextDirection textDirection}) {
    if (_phase != NotebookSwitcherPhase.idle &&
        !(_phase == NotebookSwitcherPhase.closing &&
            _origin == NotebookSwitcherOrigin.edge &&
            _landingEntry == null)) {
      return;
    }
    final pane = host.paneRect;
    if (pane == null) return;
    _pane = pane;
    _directionSign = textDirection == TextDirection.ltr ? 1 : -1;
    _origin = NotebookSwitcherOrigin.edge;
    _landingEntry = null;
    _dragSelecting = false;
    _openAnchorY = null;
    _hovered = null;
    _reverse = false;
    final caught = _phase == NotebookSwitcherPhase.closing;
    stage.stop();
    // 余下的距离不够长成面板时缩短这一段，保证一定拉得满。
    final edgeX = _directionSign > 0 ? pane.left : pane.right;
    final travelled = (position.dx - edgeX).abs();
    final room = pane.width - 16 - travelled - armDistance;
    _span = math.max(
      shortestSpan,
      math.min((pane.width * 0.4).clamp(minSpan, maxSpan), room),
    );
    _pull = caught ? _pullForStage(stage.value) : 0;
    _armed = _pull >= armDistance;
    // 收回途中被新的手指接住算重新唤出：面板悬浮到这根手指的高度（浮层把
    // 位置变化做成滑过去）；没接住时等武装再定。
    _panelAnchor = caught && _armed
        ? NotebookPanelAnchor.center(position.dy)
        : null;
    _fingerY = position.dy;
    _setPhase(NotebookSwitcherPhase.dragging);
    if (!caught) {
      stage.value = 0;
      armPop.value = 0;
    }
    _showPortal();
  }

  /// 在卡组浮层（面板或遮罩）上横向起手：按同一根进度轴跟手——往回拉时
  /// 卡组缩回左缘胶囊、胶囊再缩进边缘，与右滑拉出逐帧对称；往右拉则重新
  /// 长开。打开着、正弹回打开、或正收回（返回键、点遮罩，不是选中后的
  /// 落地）时都能接住：收回途中浮层还盖着页面，列表上的右滑到不了页面的
  /// 手势层，必须在这里接住，否则要等动画走完再滑一次。
  ///
  /// 从切换胶囊打开的卡组：完全打开时起手改为收向左缘（胶囊此刻露回原处，
  /// 进度在 2 上换起点不会跳）；正收向胶囊途中被接住则仍以胶囊为起点，
  /// 往回拉最多回到胶囊处，松手收回时也收进胶囊。纵向中心跟着手指。
  void closeDragStart(Offset position) {
    final closing = _phase == NotebookSwitcherPhase.closing;
    final catchable =
        _phase == NotebookSwitcherPhase.open ||
        (closing && _landingEntry == null);
    final pane = _pane;
    if (!catchable || pane == null) return;
    stage.stop();
    // 收回途中被接住：多半是想重新拉开，算在这根手指处重新唤出——面板悬浮
    // 到手指的高度（浮层把位置变化做成滑过去），不再停在上次打开的地方；
    // 打开着时起手只是往回收，位置不动。以切换胶囊为起点时仍贴在胶囊下方。
    if (closing && _origin == NotebookSwitcherOrigin.edge) {
      _panelAnchor = NotebookPanelAnchor.center(position.dy);
    }
    if (_origin == NotebookSwitcherOrigin.chip) {
      _span = (pane.width * 0.4).clamp(minSpan, maxSpan);
      if (stage.value >= 1.98) {
        _origin = NotebookSwitcherOrigin.edge;
        chipHidden.value = false;
      } else {
        chipHidden.value = true;
      }
    }
    _deck?.autoScroll(null);
    _deck?.lift(null);
    _reverse = true;
    _dragSelecting = false;
    _openAnchorY = null;
    _hovered = null;
    _fingerY = position.dy;
    _pull = _pullForStage(stage.value);
    _armed = _pull >= armDistance;
    _setPhase(NotebookSwitcherPhase.dragging);
  }

  void dragUpdate(Offset position, double deltaX) {
    if (_phase != NotebookSwitcherPhase.dragging) return;
    _fingerY = position.dy;
    if (_dragSelecting) {
      _updateHover(position);
      _deck?.autoScroll(position);
      notifyListeners();
      return;
    }
    // 以切换胶囊为起点时没有左缘胶囊那一段：最多收回到胶囊处。
    final floor = _origin == NotebookSwitcherOrigin.chip ? armDistance : 0.0;
    _pull = math.max(floor, _pull + deltaX * _directionSign);
    stage.value = _stageForPull(_pull);
    _setArmed(_pull >= armDistance);
    // 拉满一次就记下手指高度；之后手指往卡片那边斜着挪（横向略回收）仍算
    // 在拉开的卡组上，上下移过溢出距离即进入拖选。明显往回收（进度跌破
    // 一半）才作废，回到跟手开合。
    if (_reverse) {
      // 往回收：只管开合，不进拖选。
    } else if (stage.value >= 1.98) {
      _openAnchorY ??= position.dy;
    } else if (stage.value < 1.5) {
      _openAnchorY = null;
    }
    final anchor = _reverse ? null : _openAnchorY;
    if (anchor != null && (position.dy - anchor).abs() > dragSelectSlop) {
      _dragSelecting = true;
      // 横向不再控制开合：没拉满的那一点弹回到完全打开。
      _springStage(2, ExpressiveMotion.springSpatial);
      _updateHover(position);
    }
    notifyListeners();
  }

  void dragEnd(double velocityX) {
    if (_phase != NotebookSwitcherPhase.dragging) return;
    _deck?.autoScroll(null);
    if (_dragSelecting) {
      _dragSelecting = false;
      final entry = _hovered;
      _hovered = null;
      if (entry != null) {
        unawaited(HapticFeedback.lightImpact());
        unawaited(select(entry));
        return;
      }
      _deck?.lift(null);
      _settleOpen(0);
      return;
    }
    final velocity = velocityX * _directionSign;
    final bool open;
    if (_reverse) {
      // 往回收：甩动方向优先，否则看收回过没过一半。
      _reverse = false;
      open = velocity >= cancelFlingVelocity
          ? true
          : velocity <= -cancelFlingVelocity
          ? false
          : stage.value >= 1.5;
    } else {
      open = _armed && velocity > -cancelFlingVelocity;
    }
    if (open) {
      _settleOpen(velocity / _span);
    } else {
      _closeTo(_closeTarget, velocity: velocity / _span);
    }
  }

  /// 不选中、只是收起时回到哪里：以切换胶囊为起点且胶囊还在屏上时收进
  /// 胶囊，否则收回左缘。
  NotebookSwitcherOrigin get _closeTarget =>
      _origin == NotebookSwitcherOrigin.chip && host.chipRect != null
      ? NotebookSwitcherOrigin.chip
      : NotebookSwitcherOrigin.edge;

  void dragCancel() {
    if (_phase != NotebookSwitcherPhase.dragging) return;
    _deck?.autoScroll(null);
    _deck?.lift(null);
    _dragSelecting = false;
    _hovered = null;
    _reverse = false;
    if (stage.value >= 1.5) {
      _settleOpen(0);
    } else {
      _closeTo(_closeTarget);
    }
  }

  Offset? _lastPosition;

  /// 拖选途中卡组自动滚动了一步：手指下的卡片变了，按上次的手指位置重新
  /// 命中。
  void refreshHover() {
    final position = _lastPosition;
    if (!_dragSelecting || position == null) return;
    _updateHover(position);
  }

  void _updateHover(Offset position) {
    _lastPosition = position;
    final entry = _deck?.entryAt(position);
    if (entry?.key == _hovered?.key) return;
    _hovered = entry;
    _deck?.lift(entry?.key);
    if (entry != null) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void _setArmed(bool armed) {
    if (armed == _armed) return;
    _armed = armed;
    // 右滑拉出：武装那一刻手指的高度定下面板悬浮的位置；拉回阈值以内再
    // 换个高度武装，面板跟着换位置。往回收时位置不动。
    if (_phase == NotebookSwitcherPhase.dragging && !_reverse) {
      _panelAnchor = armed ? NotebookPanelAnchor.center(_fingerY) : null;
    }
    if (armed) {
      // 只在越过阈值的那一下震；拉回去不震。
      unawaited(HapticFeedback.lightImpact());
      ExpressiveMotion.springTo(
        host.context,
        armPop,
        1,
        spring: ExpressiveMotion.springSpatialFast,
      );
    } else {
      ExpressiveMotion.springTo(
        host.context,
        armPop,
        0,
        spring: ExpressiveMotion.springPage,
      );
    }
  }

  // ==================== 打开、选择与收起 ====================

  /// 从切换胶囊打开：容器从胶囊的矩形长成面板。胶囊被标签条横向滚出一截
  /// （不完整）时改从左缘长出，纵向对着列表栏中间。
  void openFromChip({required TextDirection textDirection}) {
    if (_phase != NotebookSwitcherPhase.idle) return;
    final pane = host.paneRect;
    if (pane == null) return;
    final chip = host.chipRect;
    _pane = pane;
    _directionSign = textDirection == TextDirection.ltr ? 1 : -1;
    _landingEntry = null;
    _armed = true;
    armPop.value = 1;
    if (chip != null) {
      _origin = NotebookSwitcherOrigin.chip;
      _fingerY = chip.center.dy;
      _panelAnchor = NotebookPanelAnchor.top(chip.bottom + panelGap);
      stage.value = 1;
      chipHidden.value = true;
    } else {
      _origin = NotebookSwitcherOrigin.edge;
      _fingerY = pane.center.dy;
      _panelAnchor = NotebookPanelAnchor.center(_fingerY);
      stage.value = 0;
    }
    _setPhase(NotebookSwitcherPhase.open);
    _showPortal();
    _springStage(2, ExpressiveMotion.springSpatial);
  }

  /// 系统返回 / Esc：卡组里的长按菜单开着时先收起菜单（日记页的 PopScope
  /// 拦在菜单的局部历史之前，菜单自己收不到返回），返回是否收起了菜单。
  bool closeDeckMenu() => _deck?.closeMenu() ?? false;

  /// 收起，不切换：回到来处（左缘或切换胶囊）。
  void close() {
    if (_phase == NotebookSwitcherPhase.idle ||
        _phase == NotebookSwitcherPhase.closing) {
      return;
    }
    _deck?.autoScroll(null);
    _deck?.lift(null);
    _dragSelecting = false;
    _closeTo(_closeTarget);
  }

  /// 立即消失，不播动画（切 Tab、关闭日记本功能、页面销毁前）。
  void dismissImmediately() {
    if (_phase == NotebookSwitcherPhase.idle) return;
    stage.stop();
    _finish();
  }

  /// 选中卡组里的一项：抽出 → （上锁的先验证）→ 提交切换并收进切换胶囊
  /// （胶囊不在屏上时收回左缘）。选的就是当前范围时只收起。
  Future<void> select(NotebookDeckEntry entry) async {
    if (_phase != NotebookSwitcherPhase.open &&
        _phase != NotebookSwitcherPhase.dragging) {
      return;
    }
    if (!entry.selectable) return;
    if (host.isCurrent(entry)) {
      _deck?.lift(null);
      close();
      return;
    }
    _setPhase(NotebookSwitcherPhase.selecting);
    _deck?.lift(null);
    _deck?.pullOut(entry.key);
    final allowed = await host.authorize(entry);
    if (_phase != NotebookSwitcherPhase.selecting) return;
    if (!allowed) {
      _deck?.pullOut(null);
      _deck?.shake(entry.key);
      _setPhase(NotebookSwitcherPhase.open);
      return;
    }
    final chip = host.chipRect;
    _landingEntry = entry;
    host.commit(entry);
    _closeTo(
      chip != null ? NotebookSwitcherOrigin.chip : NotebookSwitcherOrigin.edge,
    );
  }

  void _settleOpen(double velocity) {
    _setPhase(NotebookSwitcherPhase.open);
    _springStage(2, ExpressiveMotion.springSpatial, velocity: velocity);
  }

  void _closeTo(NotebookSwitcherOrigin target, {double velocity = 0}) {
    _origin = target;
    _setPhase(NotebookSwitcherPhase.closing);
    if (target == NotebookSwitcherOrigin.chip) {
      chipHidden.value = true;
      _landInChip();
    } else {
      if (_armed) _setArmed(false);
      _springStage(
        0,
        ExpressiveMotion.springPage,
        velocity: velocity,
        tolerance: _closeTolerance,
        onDone: _finish,
      );
    }
  }

  /// 收回左缘的弹簧停稳判定：差一个像素以内就算到了。默认的极小容差会让
  /// 弹簧在终点前拖一段看不出来的尾巴，浮层多挂几百毫秒、挡住点按与右滑。
  static const Tolerance _closeTolerance = Tolerance(
    distance: 0.004,
    velocity: 0.06,
  );

  /// 收进切换胶囊：与新建日记收进角标同一套落点动效——容器按
  /// [ExpressiveMotion.morphLandCurve] 带着余速撞进胶囊（不在终点前减速
  /// 到停、拖一段尾巴），撞上的同一帧换回真胶囊，由胶囊接着回弹
  /// （[ExpressiveMotion.morphLandBounce]）。离胶囊越近走得越快。
  void _landInChip() {
    _stageTarget = 1;
    if (_reduceMotion) {
      stage.value = 1;
      _finish();
      return;
    }
    final remaining = ((stage.value - 1) / 1).clamp(0.35, 1.0);
    stage
        .animateTo(
          1,
          duration: ExpressiveMotion.morphLand * remaining,
          curve: ExpressiveMotion.morphLandCurve,
        )
        .then((_) {
          if (_stageTarget != 1 || _phase != NotebookSwitcherPhase.closing) {
            return;
          }
          _finish();
          // 胶囊接住容器：先被压小一点再弹回。
          chipBounce.value = 1;
          ExpressiveMotion.springTo(
            host.context,
            chipBounce,
            1,
            spring: ExpressiveMotion.morphLandBounce,
            kick: ExpressiveMotion.morphLandKick(0.08),
          );
        });
  }

  void _springStage(
    double target,
    SpringDescription spring, {
    double velocity = 0,
    Tolerance tolerance = const Tolerance(distance: 0.0005, velocity: 0.005),
    VoidCallback? onDone,
  }) {
    _stageTarget = target;
    if (_reduceMotion) {
      stage.value = target;
      onDone?.call();
      return;
    }
    final current = stage.isAnimating ? stage.velocity : 0.0;
    stage
        .animateWith(
          SpringSimulation(
            spring,
            stage.value,
            target,
            current + velocity.clamp(-12.0, 12.0),
            tolerance: tolerance,
            snapToEnd: true,
          ),
        )
        .then((_) {
          if (_stageTarget == target) onDone?.call();
        });
  }

  void _finish() {
    _pull = 0;
    _armed = false;
    _dragSelecting = false;
    _reverse = false;
    _hovered = null;
    _openAnchorY = null;
    _panelAnchor = null;
    armPop.value = 0;
    stage.value = 0;
    _stageTarget = 0;
    chipHidden.value = false;
    _setPhase(NotebookSwitcherPhase.idle);
    if (portal.isShowing) portal.hide();
    _landingEntry = null;
  }

  void _showPortal() {
    if (!portal.isShowing) portal.show();
  }

  void _setPhase(NotebookSwitcherPhase phase) {
    if (phase == _phase) return;
    _phase = phase;
    notifyListeners();
  }

  // ==================== 拉动距离 ↔ 进度 ====================

  double _stageForPull(double pull) {
    if (pull <= armDistance) {
      return (1 - math.exp(-pull / pullRubber)) /
          (1 - math.exp(-armDistance / pullRubber));
    }
    final progress = (pull - armDistance) / _span;
    if (progress <= 1) return 1 + progress;
    // 拉满之后再拉只多长一点点，手感上“到头了”但不是硬停。
    return 2 + 0.04 * (1 - math.exp(-(progress - 1) * _span / 80));
  }

  double _pullForStage(double value) {
    if (value <= 0) return 0;
    if (value <= 1) {
      final scaled = value * (1 - math.exp(-armDistance / pullRubber));
      return -pullRubber * math.log(1 - scaled);
    }
    return armDistance + math.min(value - 1, 1) * _span;
  }

  @override
  void dispose() {
    stage.dispose();
    armPop.dispose();
    chipBounce.dispose();
    chipHidden.dispose();
    super.dispose();
  }
}
