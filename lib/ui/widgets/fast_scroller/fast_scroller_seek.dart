import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'fast_scroller_geometry.dart';

/// 把列表带到第 N 项的驱动：快速滚动条拖动、桌面点按轨道时由它逐帧移动
/// 列表。
///
/// 输入：目标项序（连续值）与是否仍被按住；输出：经 [_FastScrollSeekActivity]
/// 写入的滚动位置，目标超出已加载范围时经 [onNeedItems] 请求加载。
///
/// 状态与时机：
/// - 每帧（Ticker）按最新布局重算目标位置：目标项已布局时精确，否则按平均
///   高度估算；到了估算位置后下一帧它已布局，再校正一次（最多
///   [_maxRefines] 次），所以落点就是那一项。
/// - 近处（不超过一步）直接到位，跟手无延迟；远处每帧最多移动一步：
///   SliverList 只能逐项布局途经的卡片，一帧跨过上千篇会长时间卡住，分到
///   几十帧里，列表像被快速拉过去。减少动画时不限步。
/// - 到达后：仍按住时停在那里等下一个目标；松手后结束；目标在还没加载的
///   部分时等数据（[resume] 由宿主在滚动范围变化时调用），期间交回空闲
///   状态，不挡列表的点按。
/// - 用户按住列表拖动、或别处开始了新的滚动（如回到顶部）时，滚动活动被
///   取代，本次移动随之取消。
/// - 兜底：同一个目标让移动方向连续翻转 [_maxReversals] 次（换算与布局
///   互相影响、来回追不到）时按已到达处理，不让列表每帧来回跳。
class FastScrollSeek {
  FastScrollSeek({
    required TickerProvider vsync,
    required this.positionOf,
    required this.geometryOf,
    required this.itemCount,
    required this.reduceMotion,
    this.onNeedItems,
    this.onSettled,
  }) {
    _ticker = vsync.createTicker(_tick);
  }

  /// 远距离移动时每帧最多跨过的项数（另有至少 [_minStepViewports] 屏）。
  static const double _maxItemsPerFrame = 32;
  static const double _minStepViewports = 3;
  static const int _maxRefines = 4;
  static const int _maxReversals = 2;

  /// 估算速度用的帧率：只用来让图片推迟解码的判断生效，不必精确。
  static const double _framesPerSecond = 60;

  final ScrollPosition? Function() positionOf;
  final FastScrollListGeometry? Function() geometryOf;
  final int Function() itemCount;
  final bool Function() reduceMotion;
  final ValueChanged<int>? onNeedItems;

  /// 松手后的移动结束（到达或被取消）时调用。
  final VoidCallback? onSettled;

  late final Ticker _ticker;
  double? _target;
  bool _holding = false;
  int _refines = 0;

  /// 同一目标下最近一步的方向（-1 / 0 / 1）与方向翻转的次数。
  int _lastDirection = 0;
  int _reversals = 0;
  _FastScrollSeekActivity? _activity;

  /// 是否有尚未完成的移动（含等数据）。
  bool get isActive => _target != null;

  /// 移动到第 [index] 项；[holding] 为 true 表示滚动条仍被按住，到达后不
  /// 结束。
  void seekTo(double index, {required bool holding}) {
    if (_target != index) {
      _refines = 0;
      _lastDirection = 0;
      _reversals = 0;
    }
    _target = index;
    _holding = holding;
    _startTicker();
  }

  /// 松开滚动条：到达后结束本次移动。
  void release() {
    if (!_holding) {
      return;
    }
    _holding = false;
    if (_target == null) {
      return;
    }
    _startTicker();
  }

  /// 布局或数据变了（新的一页到了、滚动范围变化）：有未完成的移动时继续。
  void resume() {
    if (_target != null) {
      _startTicker();
    }
  }

  /// 放弃未完成的移动，交回空闲状态。
  void cancel() {
    final hadTarget = _target != null;
    _target = null;
    _holding = false;
    _ticker.stop();
    _endActivity();
    if (hadTarget) {
      onSettled?.call();
    }
  }

  void dispose() {
    _target = null;
    _ticker.dispose();
    _endActivity();
  }

  void _startTicker() {
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _tick(Duration _) {
    final index = _target;
    final position = positionOf();
    final geometry = geometryOf();
    if (index == null ||
        position == null ||
        geometry == null ||
        !position.hasContentDimensions ||
        !position.hasPixels) {
      _ticker.stop();
      return;
    }
    final total = itemCount();
    final loaded = geometry.loadedCount;
    final target = geometry.pixelsFor(index);
    final max = position.maxScrollExtent;
    final waitingForItems = total > loaded && target.pixels > max - 0.5;
    if (waitingForItems || index >= loaded - 1 && total > loaded) {
      onNeedItems?.call(total);
    }
    final goal = target.pixels.clamp(position.minScrollExtent, max);
    final distance = goal - position.pixels;
    if (distance.abs() < 0.5) {
      // 估算位置到了、那一项还没布局：下一帧它已在顶线附近布局，再校正。
      if (!target.exact && goal == target.pixels && _refines < _maxRefines) {
        _refines++;
        return;
      }
      _arrive(waitingForItems: waitingForItems);
      return;
    }
    final direction = distance.sign.toInt();
    if (_lastDirection != 0 && direction != _lastDirection) {
      _reversals++;
      if (_reversals >= _maxReversals) {
        _arrive(waitingForItems: false);
        return;
      }
    }
    _lastDirection = direction;
    final step = reduceMotion()
        ? distance
        : _limitStep(distance, position.viewportDimension, geometry);
    _moveTo(position, position.pixels + step, step * _framesPerSecond);
  }

  /// 到达目标（或判定为追不到）：仍按住时停在原地等下一个目标；目标在
  /// 还没加载的部分时先交回空闲状态（不挡点按），数据到了经 [resume]
  /// 继续；否则结束本次移动。
  void _arrive({required bool waitingForItems}) {
    _ticker.stop();
    if (_holding) {
      _activity?.settle();
    } else if (waitingForItems) {
      _endActivity();
    } else {
      _target = null;
      _endActivity();
      onSettled?.call();
    }
  }

  double _limitStep(
    double distance,
    double viewport,
    FastScrollListGeometry geometry,
  ) {
    final cap = math.max(
      viewport * _minStepViewports,
      geometry.averageExtent * _maxItemsPerFrame,
    );
    return distance.abs() <= cap ? distance : cap * distance.sign;
  }

  void _moveTo(ScrollPosition position, double pixels, double velocity) {
    var activity = _activity;
    if (activity == null) {
      if (position is! ScrollPositionWithSingleContext) {
        position.jumpTo(pixels);
        return;
      }
      late final _FastScrollSeekActivity created;
      created = _FastScrollSeekActivity(
        position,
        onReplaced: () => _handleActivityReplaced(created),
      );
      position.beginActivity(created);
      activity = _activity = created;
    }
    activity.moveTo(pixels, velocity);
  }

  /// 自己结束活动时先把引用清掉，[_handleActivityReplaced] 据此区分“被别处
  /// 取代”。
  void _endActivity() {
    final activity = _activity;
    _activity = null;
    if (activity == null) {
      return;
    }
    final position = positionOf();
    if (position is ScrollPositionWithSingleContext) {
      position.goBallistic(0);
    }
  }

  void _handleActivityReplaced(_FastScrollSeekActivity activity) {
    if (!identical(activity, _activity)) {
      return;
    }
    _activity = null;
    cancel();
  }
}

/// 快速滚动条带动列表时的滚动活动，位置由 [FastScrollSeek] 逐帧给出。
///
/// 与拖动、惯性一样是一种 ScrollActivity：期间列表忽略点按（拖动途中不会
/// 误开卡片），用户按住列表即被拖动活动取代（[onReplaced]）。报告的速度由
/// 每帧位移换算：远距离移动时远超系统阈值，图片按
/// `Scrollable.recommendDeferredLoadingForContext` 推迟解码，一闪而过的
/// 中间卡片不去解码封面；停下后速度归零，留在屏幕上的照常加载。
class _FastScrollSeekActivity extends ScrollActivity {
  _FastScrollSeekActivity(super.delegate, {required this.onReplaced});

  final VoidCallback onReplaced;
  double _velocity = 0;

  void moveTo(double pixels, double velocity) {
    _velocity = velocity;
    delegate.setPixels(pixels);
  }

  /// 停在原地等待（仍按住滚动条）：速度归零，图片可以开始加载。
  void settle() => _velocity = 0;

  @override
  bool get shouldIgnorePointer => true;

  @override
  bool get isScrolling => true;

  @override
  double get velocity => _velocity;

  @override
  void dispose() {
    onReplaced();
    super.dispose();
  }
}
