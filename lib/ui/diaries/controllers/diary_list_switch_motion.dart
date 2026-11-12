import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../widgets/launch_reveal.dart';

/// 日记列表整体切换（标签筛选、排序、布局、日记本范围）的退场 / 入场动效。
///
/// 输入：协调器调用 [exit] → 换数据前 [prepareEnter] → 换数据后 [enter]；
/// 输出：每一项（按 [slotFor] 得到的错峰槽位）此刻的不透明度 [opacityOf] 与
/// 位移 [offsetOf]，由 `DiaryListSwitchReveal` 逐项读取；无其他副作用。
///
/// 节奏：
/// - 退场（[ExpressiveMotion.fast]）：屏上所有项一起加速离开（exit 曲线）——
///   有方向时朝新标签的反方向平移 [slideDistance]，没有方向时下沉
///   [sinkDistance]，同时淡出。退场要快且整齐，不错峰；
/// - 换数据：在全部不可见时进行（[prepareEnter] 把入场归零，与换数据落在
///   同一帧）；
/// - 入场：每项各走 [ExpressiveMotion.medium]，自上而下错开 [stagger]（与
///   启动编排里卡片的节奏同源），第 [maxStaggerSlot] 项之后同步（已在首屏
///   之外，再错峰只会拖长整段）。有方向时从新标签那一侧平移进来，没有方向
///   时自下浮起；位移走 spatial 微弹簧落位，透明度走 effects。
///
/// 打断：退场开始时停住入场、从当前画面出发——不透明度取“入场 ×（1 − 退场）”，
/// 位移两者相加，连点时不会先跳回满不透明再淡出。退场方向在开始时锁定，
/// 途中换方向只影响下一段入场。减少动画时协调器不调用本类的动画，只等数据
/// 到齐直接替换。
class DiaryListSwitchMotion extends ChangeNotifier {
  DiaryListSwitchMotion({required TickerProvider vsync})
    : _exit = AnimationController(vsync: vsync, duration: exitDuration),
      _enter = AnimationController(
        vsync: vsync,
        duration: enterSpan,
        value: 1,
      ) {
    _exit.addListener(notifyListeners);
    _enter.addListener(notifyListeners);
  }

  /// 有方向时进出场的水平位移（对齐 M3 shared axis X 的 30dp）。
  static const double slideDistance = 30;

  /// 没有方向时退场下沉的距离：只是“让位”，比入场的浮起短。
  static const double sinkDistance = 12;

  /// 没有方向时入场浮起的距离，与启动编排里卡片的上浮一致。
  static const double riseDistance = 20;

  /// 错峰的最大槽位：第 5 项（槽位 4）之后与它同步。
  static const int maxStaggerSlot = 4;

  static const Duration exitDuration = ExpressiveMotion.fast;
  static const Duration itemDuration = ExpressiveMotion.medium;

  /// 相邻两项的入场间隔：取启动编排里卡片的错峰（整段编排的 6%，约 30ms），
  /// 列表切换与冷启动是同一种“逐张落位”的节奏。
  static final Duration stagger = LaunchReveal.duration * 0.06;

  /// 整段入场：最后一个槽位开始后再走完一项的时长。
  static final Duration enterSpan = itemDuration + stagger * maxStaggerSlot;

  final AnimationController _exit;
  final AnimationController _enter;

  /// 退场方向（开始时锁定）：+1 新内容从右边来、旧内容往左走；-1 相反；
  /// 0 为纵向。
  int _exitDirection = 0;

  /// 入场方向，含义同 [_exitDirection]。
  int _enterDirection = 0;

  /// 入场时第一个被构建的项的下标：错峰从它算起。列表回到开头时就是 0；
  /// 没有回到开头（章节切换、布局切换）时是视口顶部附近的那一项，屏上
  /// 第一张卡片照样第一个落位。
  int? _anchor;

  /// 是否处在静止的落定态（没有退场、入场已走完）。
  bool get isIdle =>
      !_exit.isAnimating &&
      !_enter.isAnimating &&
      _exit.value == 0 &&
      _enter.value == 1;

  /// 列表是否已经完全退场（看不见）。
  bool get isHidden => _exit.value >= 1 || _enter.value <= 0;

  /// 第 [index] 项的错峰槽位。必须在项的 build 里调用（不是逐帧的 builder
  /// 里）：入场那一帧列表按下标顺序构建，第一次调用定下锚点。
  int slotFor(int index) {
    final anchor = _anchor ??= index;
    return (index - anchor).clamp(0, maxStaggerSlot);
  }

  /// 槽位 [slot] 此刻的入场进度（0 → 1，未过曲线）。
  double _enterProgress(int slot) {
    final span = enterSpan.inMicroseconds;
    final start = (stagger * slot).inMicroseconds;
    final elapsed = _enter.value * span - start;
    return (elapsed / itemDuration.inMicroseconds).clamp(0.0, 1.0);
  }

  /// 槽位 [slot] 此刻的不透明度。
  double opacityOf(int slot) {
    final entered = ExpressiveMotion.effects.transform(_enterProgress(slot));
    final exited = ExpressiveMotion.exit.transform(_exit.value);
    return (entered * (1 - exited)).clamp(0.0, 1.0);
  }

  /// 槽位 [slot] 此刻的位移（逻辑像素，绝对坐标：正 x 向右、正 y 向下）。
  Offset offsetOf(int slot) {
    final settle = ExpressiveMotion.spatial.transform(_enterProgress(slot));
    final enterRemain = 1 - settle;
    final enter = _enterDirection == 0
        ? Offset(0, riseDistance * enterRemain)
        : Offset(_enterDirection * slideDistance * enterRemain, 0);
    final exited = ExpressiveMotion.exit.transform(_exit.value);
    final exit = _exitDirection == 0
        ? Offset(0, sinkDistance * exited)
        : Offset(-_exitDirection * slideDistance * exited, 0);
    return enter + exit;
  }

  /// 退场：所有项朝 [direction] 的反方向离开并淡出，完成时列表不可见。
  ///
  /// 已经完全退场时立即返回；退场进行中再次调用时沿用已锁定的方向接着走。
  /// 页面销毁时控制器被释放，返回的 future 不再完成（协调器在每个 await
  /// 之后都检查 mounted，不依赖它完成）。
  Future<void> exit(int direction) async {
    if (isHidden) {
      return;
    }
    if (!_exit.isAnimating) {
      _exitDirection = direction;
    }
    // 入场停在当前进度：退场从此刻的画面出发（见类注释“打断”）。
    _enter.stop();
    await _exit.animateTo(1, duration: exitDuration, curve: Curves.linear);
  }

  /// 换数据之前调用（与换数据同一帧）：入场归零、退场复位，所有项仍不可见；
  /// 记下入场方向，清掉错峰锚点。
  void prepareEnter(int direction) {
    _enterDirection = direction;
    _anchor = null;
    _exit.value = 0;
    _enter.value = 0;
  }

  /// 换数据后的下一帧开始入场。
  Future<void> enter() =>
      _enter.animateTo(1, duration: enterSpan, curve: Curves.linear);

  /// 直接落定（减少动画）：不淡不移。
  void settle() {
    _exit.value = 0;
    _enter.value = 1;
  }

  @override
  void dispose() {
    _exit.dispose();
    _enter.dispose();
    super.dispose();
  }
}
