import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../app/theme/expressive_motion.dart';

/// [SnapPanel] 的三个停靠档位，自下而上。
enum SnapPanelStop { collapsed, half, expanded }

/// [SnapPanel] 的位置状态：面板可见高度、三档高度、拖动跟手与松手吸附。
///
/// 输入：拖动位移与松手速度（来自面板表头手势，或经 [SnapPanelScrollController]
/// 转交的内容拖动），以及 [SnapPanel] 布局时同步的三档高度。输出：逐帧变化的
/// [extent]——监听者是面板布局，只重新布局、不重建子树；档位只在松手选定目标或
/// 代码切换时变化，经 [stopListenable] 单独通知（读屏的档位描述只随它重建）。
///
/// 拖动过程直接映射手指位移；松手后按速度与位置选出档位，以 `medium` 时长 +
/// `spatial` 曲线补间过去，减少动画时直接到位。三档高度随屏幕尺寸、字号与系统栏
/// 变化：静止时始终停在当前档位的最新高度，拖动或吸附途中只把位置夹在新的上下限
/// 之内，吸附结束时再落到目标档位的最新高度。
class SnapPanelController extends ChangeNotifier {
  SnapPanelController({
    required TickerProvider vsync,
    SnapPanelStop initialStop = SnapPanelStop.half,
  }) : _stop = ValueNotifier<SnapPanelStop>(initialStop) {
    _animation = AnimationController.unbounded(vsync: vsync)
      ..addListener(_handleTick)
      ..addStatusListener(_handleStatus);
  }

  /// 松手时快于这个速度（逻辑像素/秒）视为甩动：朝甩动方向吸附到相邻档位；
  /// 慢于它则吸附到最近的档位。
  static const double flingVelocity = 500;

  /// 判断“已越过某档”的容差，避免停在档位上时因浮点误差被当成越过。
  static const double _tolerance = 1;

  late final AnimationController _animation;
  final ValueNotifier<SnapPanelStop> _stop;
  List<double> _stops = const <double>[0, 0, 0];
  bool _hasStops = false;
  double _extent = 0;
  bool _dragging = false;
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// 上一个停靠过的档位：点按拖动条时在中档决定下一步往哪走（见 [cycle]）。
  SnapPanelStop? _previousStop;

  /// 吸附补间时长；[SnapPanel] 每次构建时按系统“减少动态效果”解析后写入。
  Duration snapDuration = ExpressiveMotion.medium;

  /// 面板当前（或正在吸附前往）的档位。
  SnapPanelStop get stop => _stop.value;

  /// 只在档位变化时通知；拖动途中不变。
  ValueListenable<SnapPanelStop> get stopListenable => _stop;

  /// 面板当前可见高度（含表头），吸附弹簧过冲时可能略超出上下限。
  double get extent => _extent;

  /// 布局用的可见高度：弹簧在两端的过冲不让面板越过最高、最低档。
  double get layoutExtent =>
      _hasStops ? _extent.clamp(_stops.first, _stops.last).toDouble() : _extent;

  /// 指定档位的可见高度；布局之前都为 0。
  double extentOf(SnapPanelStop stop) => _stops[stop.index];

  /// 由 [SnapPanel] 在布局阶段调用，同步三档高度（自下而上不递减）。
  ///
  /// 布局中不能同步通知监听者：位置被改写时推迟到这一帧结束再通知，让依赖
  /// 位置的淡入与档位描述跟上。
  void syncStops({
    required double collapsed,
    required double half,
    required double expanded,
  }) {
    final top = expanded < collapsed ? collapsed : expanded;
    final next = <double>[
      collapsed,
      half.clamp(collapsed, top).toDouble(),
      top,
    ];
    if (_hasStops && listEquals(next, _stops)) {
      return;
    }
    _stops = next;
    _hasStops = true;
    final previous = _extent;
    _extent = _dragging || _animation.isAnimating
        ? _extent.clamp(next.first, next.last).toDouble()
        : next[stop.index];
    if (_extent != previous) {
      _scheduleNotify();
    }
  }

  /// 开始拖动：停下正在进行的吸附，从当前位置接手。
  void beginDrag() {
    _animation.stop();
    _dragging = true;
  }

  /// 把手指位移（向下为正）作用到面板，返回面板没有吃掉的部分（已到最高或
  /// 最低档时原样返回，交给调用方处理）。[limit] 给出时面板只移动到这个高度
  /// 为止，用于同一次拖动里先把面板推回原位。
  double dragBy(double fingerDelta, {double? limit}) {
    if (!_hasStops || fingerDelta == 0) {
      return fingerDelta;
    }
    var lower = _stops.first;
    var upper = _stops.last;
    if (limit != null) {
      if (fingerDelta < 0) {
        upper = limit.clamp(lower, upper).toDouble();
      } else {
        lower = limit.clamp(lower, upper).toDouble();
      }
    }
    final current = _extent.clamp(lower, upper).toDouble();
    final next = (current - fingerDelta).clamp(lower, upper).toDouble();
    // 面板变矮为正（手指向下），变高为负；剩余位移与手指位移同号。
    final consumed = current - next;
    _setExtent(next);
    return fingerDelta - consumed;
  }

  /// 拖动的来源在拖动途中被释放（如切换标签页）：这一帧结束后再吸附到最近的
  /// 档位。释放发生在卸载阶段，那时不能通知监听者重建。
  void cancelDrag() {
    _dragging = false;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && !_dragging) {
        endDrag(0);
      }
    });
  }

  /// 松手：按手指速度（向下为正，逻辑像素/秒）与当前位置选出档位并吸附。
  void endDrag(double fingerVelocity) {
    _dragging = false;
    if (!_hasStops) {
      return;
    }
    animateTo(_targetFor(-fingerVelocity));
  }

  /// 吸附到指定档位；减少动画时直接到位。
  void animateTo(SnapPanelStop target) {
    _setStop(target);
    if (!_hasStops) {
      return;
    }
    final to = extentOf(target);
    if (snapDuration == Duration.zero || (to - _extent).abs() < 0.5) {
      _animation.stop();
      _setExtent(to);
      return;
    }
    _animation.value = _extent;
    _animation.animateTo(
      to,
      duration: snapDuration,
      curve: ExpressiveMotion.spatial,
    );
  }

  /// 收起时回到中档（点按标签栏时调用：用户要看选项了）。
  void reveal() {
    if (stop == SnapPanelStop.collapsed) {
      animateTo(SnapPanelStop.half);
    }
  }

  /// 点按拖动条：两端回到中档；在中档时往来时的反方向走，于是连续点按依次
  /// 经过 中 → 上 → 中 → 下 → 中……
  void cycle() {
    animateTo(switch (stop) {
      SnapPanelStop.collapsed || SnapPanelStop.expanded => SnapPanelStop.half,
      SnapPanelStop.half =>
        _previousStop == SnapPanelStop.expanded
            ? SnapPanelStop.collapsed
            : SnapPanelStop.expanded,
    });
  }

  /// 读屏的“调大/调小”：上升或下降一档，已在最高或最低档时不动。
  void step({required bool up}) {
    final index = stop.index + (up ? 1 : -1);
    if (index < 0 || index >= SnapPanelStop.values.length) {
      return;
    }
    animateTo(SnapPanelStop.values[index]);
  }

  /// 松手选档：慢速吸附到最近的档位；甩动时朝甩动方向取相邻的下一档（[growth]
  /// 为面板变高的速度）。
  SnapPanelStop _targetFor(double growth) {
    const stops = SnapPanelStop.values;
    if (growth.abs() < flingVelocity) {
      return stops.reduce(
        (SnapPanelStop a, SnapPanelStop b) =>
            (extentOf(b) - _extent).abs() < (extentOf(a) - _extent).abs()
            ? b
            : a,
      );
    }
    if (growth > 0) {
      return stops.firstWhere(
        (SnapPanelStop s) => extentOf(s) > _extent + _tolerance,
        orElse: () => SnapPanelStop.expanded,
      );
    }
    return stops.lastWhere(
      (SnapPanelStop s) => extentOf(s) < _extent - _tolerance,
      orElse: () => SnapPanelStop.collapsed,
    );
  }

  void _setStop(SnapPanelStop value) {
    if (value != _stop.value) {
      _previousStop = _stop.value;
      _stop.value = value;
    }
  }

  void _setExtent(double value) {
    if (value == _extent) {
      return;
    }
    _extent = value;
    notifyListeners();
  }

  void _handleTick() => _setExtent(_animation.value);

  /// 吸附结束时落到目标档位的最新高度（途中档位高度可能随布局变化）。
  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _hasStops) {
      _setExtent(extentOf(stop));
    }
  }

  void _scheduleNotify() {
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _animation.dispose();
    _stop.dispose();
    super.dispose();
  }
}
