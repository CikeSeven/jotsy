import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme/expressive_motion.dart';

/// 卡组里各卡片的弹簧量：顶边位置（展开 / 收起 / 增删时滑到新位置）、
/// 抬起程度（按压、悬停、拖选，后面的卡片让位）、抽出程度（选中）与出现
/// 程度（新增 / 删除的卡片原地淡入淡出）。
///
/// 输入：卡组组件在每次条目变化时 [syncTops]，交互时 [lift] / [pullOut] /
/// [setAppear]；输出：各量此刻的值，经 [ChangeNotifier] 逐帧
/// 通知（卡组的 Flow 只重绘、不重排）。
///
/// 只用一个 [Ticker]，各弹簧按共同的时钟求值：改目标时从此刻的值与速度
/// 出发接着走（[DeckSpring.retarget]），不会像每次重启 AnimationController
/// 那样在第一帧拿到 elapsed = 0 而停一下——手指连续移动时抬起的那张也一直
/// 跟着动。所有弹簧都停稳后停掉 Ticker；减少动画时一律直接落位。
class NotebookDeckMotion extends ChangeNotifier {
  NotebookDeckMotion({
    required TickerProvider vsync,
    required this.reduceMotion,
  }) {
    _ticker = vsync.createTicker(_tick);
  }

  /// 此刻是否减少动画（宿主读系统设置）：是则一律直接落位。
  final bool Function() reduceMotion;
  late final Ticker _ticker;

  /// 共同时钟：Ticker 停下时记住走到哪，重新启动后接着累加。
  Duration _base = Duration.zero;
  Duration _now = Duration.zero;

  final Map<String, DeckSpring> _tops = <String, DeckSpring>{};
  final Map<String, DeckSpring> _lift = <String, DeckSpring>{};
  final Map<String, DeckSpring> _pull = <String, DeckSpring>{};
  final Map<String, DeckSpring> _appear = <String, DeckSpring>{};

  String? _lifted;
  String? _pulled;

  /// 此刻被抬起的卡片 key（没有为 null）。
  String? get lifted => _lifted;

  double _time() => _now.inMicroseconds / Duration.microsecondsPerSecond;

  /// [key] 此刻的顶边位置；没登记过时为 null。
  double? top(String key) => _tops[key]?.valueAt(_time());

  /// [key] 此刻的抬起程度（0–1，弹簧可略越界）。
  double liftOf(String key) => _lift[key]?.valueAt(_time()) ?? 0;

  /// [key] 此刻的抽出程度（0–1）。
  double pullOf(String key) => _pull[key]?.valueAt(_time()) ?? 0;

  /// [key] 此刻的出现程度（0–1），没登记过为 1。
  double appearOf(String key) => _appear[key]?.valueAt(_time()) ?? 1;

  /// [key] 的顶边、出现程度都已停稳。
  bool settled(String key) {
    final t = _time();
    return (_tops[key]?.isDone(t) ?? true) && (_appear[key]?.isDone(t) ?? true);
  }

  /// 按新的目标位置更新各卡片：已有的弹簧滑过去；新出现的从 [startFrom]
  /// 给的位置（子本从上级底下抽出）出发，没给时直接放在目标上。不在
  /// [targets] 里的 key 原样保留（离场的残影由卡组自己决定何时 [forget]）。
  void syncTops(
    Map<String, double> targets, {
    Map<String, double> startFrom = const <String, double>{},
  }) {
    for (final entry in targets.entries) {
      final spring = _tops[entry.key];
      if (spring == null) {
        final from = startFrom[entry.key];
        final created = DeckSpring(from ?? entry.value);
        _tops[entry.key] = created;
        if (from != null && from != entry.value) {
          _retarget(created, entry.value, ExpressiveMotion.springSpatial);
        }
      } else if (spring.target != entry.value) {
        _retarget(spring, entry.value, ExpressiveMotion.springSpatial);
      }
    }
  }

  /// 让 [key] 滑到 [target]（离场的残影收回上级底下用）。
  void moveTop(String key, double target) {
    final spring = _tops[key];
    if (spring == null) return;
    _retarget(spring, target, ExpressiveMotion.springSpatial);
  }

  /// [key] 的出现程度弹向 [target]（0 看不见、1 完整）。
  void setAppear(String key, double target, {bool instant = false}) {
    final spring = _appear.putIfAbsent(key, () => DeckSpring(1));
    if (instant) {
      spring.jump(target);
      _schedule();
      return;
    }
    _retarget(spring, target, ExpressiveMotion.springSpatial);
  }

  /// 抬起 [key]（null 放下全部）：它后面的卡片让位，自己右移、微微放大。
  void lift(String? key) {
    if (key == _lifted) return;
    final previous = _lifted;
    _lifted = key;
    if (previous != null) {
      _retarget(_lift[previous]!, 0, ExpressiveMotion.springSpatialFast);
    }
    if (key != null) {
      _retarget(
        _lift.putIfAbsent(key, () => DeckSpring(0)),
        1,
        ExpressiveMotion.springSpatialFast,
      );
    }
  }

  /// 抽出选中的 [key]（null 放回）。
  void pullOut(String? key) {
    if (key == _pulled) return;
    final previous = _pulled;
    _pulled = key;
    if (previous != null) {
      _retarget(_pull[previous]!, 0, ExpressiveMotion.springSpatialFast);
    }
    if (key != null) {
      _retarget(
        _pull.putIfAbsent(key, () => DeckSpring(0)),
        1,
        ExpressiveMotion.springSpatialFast,
      );
    }
  }

  /// 不再跟踪 [key]（离场的残影走完、条目被删）。
  void forget(String key) {
    _tops.remove(key);
    _lift.remove(key);
    _pull.remove(key);
    _appear.remove(key);
    if (_lifted == key) _lifted = null;
    if (_pulled == key) _pulled = null;
  }

  /// 所有量直接落到目标（打开卡组的第一帧、减少动画）。
  void settleAll() {
    for (final map in <Map<String, DeckSpring>>[_tops, _lift, _pull, _appear]) {
      for (final spring in map.values) {
        spring.jump(spring.target);
      }
    }
    notifyListeners();
  }

  void _retarget(DeckSpring spring, double target, SpringDescription physics) {
    if (reduceMotion()) {
      spring.jump(target);
    } else {
      spring.retarget(target, _time(), physics);
    }
    _schedule();
  }

  void _schedule() {
    if (!_ticker.isActive) {
      _ticker.start();
    }
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    _now = _base + elapsed;
    final t = _time();
    notifyListeners();
    final busy =
        _tops.values.any((s) => !s.isDone(t)) ||
        _lift.values.any((s) => !s.isDone(t)) ||
        _pull.values.any((s) => !s.isDone(t)) ||
        _appear.values.any((s) => !s.isDone(t));
    if (!busy) {
      _ticker.stop();
      _base = _now;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// 可随时改目标的弹簧值：按共同时钟（秒）求值，改目标时带着此刻的速度
/// 接着走。
class DeckSpring {
  DeckSpring(double value) : _target = value, _rest = value;

  double _target;

  /// 没有模拟时的静止值。
  double _rest;
  SpringSimulation? _simulation;
  double _start = 0;

  double get target => _target;

  double valueAt(double time) {
    final simulation = _simulation;
    if (simulation == null) return _rest;
    return simulation.x(time - _start);
  }

  double velocityAt(double time) {
    final simulation = _simulation;
    if (simulation == null) return 0;
    return simulation.dx(time - _start);
  }

  bool isDone(double time) {
    final simulation = _simulation;
    return simulation == null || simulation.isDone(time - _start);
  }

  void retarget(double target, double time, SpringDescription spring) {
    final value = valueAt(time);
    final velocity = isDone(time) ? 0.0 : velocityAt(time);
    _target = target;
    if (value == target && velocity == 0) {
      _simulation = null;
      _rest = target;
      return;
    }
    _simulation = SpringSimulation(
      spring,
      value,
      target,
      velocity,
      tolerance: const Tolerance(distance: 0.01, velocity: 0.05),
      snapToEnd: true,
    );
    _start = time;
  }

  void jump(double value) {
    _simulation = null;
    _rest = value;
    _target = value;
  }
}
