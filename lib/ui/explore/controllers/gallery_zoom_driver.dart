import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import '../models/gallery_grid.dart';
import '../models/gallery_level.dart';
import '../models/gallery_morph_plan.dart';
import '../models/gallery_pinch.dart';
import 'gallery_morph_images.dart';

/// 一段换档过渡：从 [from] 档走向 [to] 档（[to] 与 [from] 相同表示已到
/// 最大 / 最小一档，只做阻尼缩放），几何见 [plan]；终点档停在滚动偏移
/// [toOffset]。
class GalleryMorph {
  GalleryMorph({
    required this.plan,
    required this.from,
    required this.to,
    required this.fromOffset,
    required this.toOffset,
  });

  final GalleryMorphPlan plan;
  final GalleryZoom from;
  final GalleryZoom to;
  final double fromOffset;
  final double toOffset;

  bool get rubberBand => from == to;

  /// 终点档与起点档的格子边长比。
  double get ratio => plan.fromCell > 0 ? plan.toCell / plan.fromCell : 1;
}

/// 媒体画廊的捏合换档驱动（小米相册式）：顶栏与页面不动，只有图片跟着
/// 手指——每张图从当前档的位置与大小连续走到目标档的位置与大小，日期标题
/// 随所在组的第一张图移动、前半程旧标题淡出后半程新标题淡入。
///
/// 输入：指针 / 触控板 / Ctrl + 滚轮；输出：当前过渡 [morph]（为 null 时
/// 显示正式网格）、逐帧的进度 [progress] / 阻尼比例 [rubberScale] 与焦点
/// [focal]（本对象即画布的 repaint 信号），结束时经 [onCommit] 换档。
///
/// 状态与时机：
/// - 两根手指落下开始一次手势，焦点取两指中点，此后不动；正式网格此时
///   隐藏、不重建，过渡全部画在一块画布上（见 `GalleryMorphLayer`），每帧
///   只重画，不布局、不建组件。
/// - 手指比例 < 1 走向缩小一档、> 1 走向放大一档（1 附近的死区里沿用
///   已选的方向）；进度到 1 就把终点当成新起点，接着走向再下一档——一次
///   手势可连跨几档，正式网格要到手势结束才按最终档位重建一次。
/// - 手指少于两根时松手：进度过 [GalleryPinch.commitThreshold] 用弹簧走完，
///   否则弹回起点；终点 / 起点若不是正式网格当前的档位与位置，经
///   `correctPixels` 把滚动位置改到那里并经 [onCommit] 换档，同一帧撤下
///   画布。
/// - [frozen]：手势与弹簧期间为 true，宿主的滚动物理据此吞掉拖动与惯性；
///   手指全部抬起、弹簧结束后才解除（放在微任务里：抬起的那次事件随后才
///   轮到列表的拖动结束，不能让它甩出惯性）。
/// - [suppressTaps]：本轮按下过两根手指时，抬起时的点按 / 长按不算数。
class GalleryZoomDriver extends ChangeNotifier {
  GalleryZoomDriver({
    required TickerProvider vsync,
    required this.zoomOf,
    required this.gridFor,
    required this.positionOf,
    required this.trailingExtentOf,
    required this.settleDuration,
    required this.sourceOf,
    required this.providerFor,
    required this.liveImageOf,
    required this.imageConfigurationOf,
    required this.onCommit,
  }) {
    _settle = AnimationController(vsync: vsync)
      ..addListener(_handleSettleTick)
      ..addStatusListener(_handleSettleStatus);
  }

  final GalleryZoom Function() zoomOf;
  final GalleryGrid Function(GalleryZoom zoom) gridFor;
  final ScrollPosition? Function() positionOf;

  /// 网格下方还有多高的内容（页脚），终点档的滚动范围要算上它。
  final double Function() trailingExtentOf;

  /// 松手后弹簧收尾的时长（宿主经 `ExpressiveMotion.duration` 解析；减少
  /// 动画时为 0，直接落到终点）。
  final Duration Function() settleDuration;
  final String Function(int index) sourceOf;
  final ImageProvider Function(String source, GalleryZoom zoom) providerFor;
  final ui.Image? Function(String source) liveImageOf;
  final ImageConfiguration Function() imageConfigurationOf;
  final ValueChanged<GalleryZoom> onCommit;

  /// 当前过渡；为 null 时显示正式网格。只在过渡开始、连跨下一档与结束时
  /// 变化（宿主据此显隐画布与正式网格），逐帧的变化走 [notifyListeners]。
  final ValueNotifier<GalleryMorph?> morph = ValueNotifier<GalleryMorph?>(null);
  final ValueNotifier<bool> frozen = ValueNotifier<bool>(false);

  /// 手指比例离 1 不到这么多时不改方向。
  static const double _deadZone = 0.02;

  late final AnimationController _settle;
  final Map<int, Offset> _pointers = <int, Offset>{};
  GalleryMorphImages? _images;

  Offset _focal = Offset.zero;

  /// 手指比例的基准：触摸为两指距离，触控板为事件的累计比例。为 null 表示
  /// 不在捏合中。
  double? _base;
  double _scale = 1;
  double _progress = 0;
  double _rubberScale = 1;
  double _settleFrom = 0;
  double _settleTo = 0;
  double _rubberFrom = 1;
  bool _suppressTaps = false;
  bool _disposed = false;

  /// 当前一段过渡的进度（0 起点档，1 终点档；弹簧可略超出）。
  double get progress => _progress;

  /// 阻尼缩放的比例（只在到头的档位继续捏时偏离 1）。
  double get rubberScale => _rubberScale;
  Offset get focal => _focal;

  /// 过渡里第 [index] 张的画面（还没有时为 null，画占位底色）。
  ui.Image? imageAt(int index) => _images?[index];

  bool get active => morph.value != null || _base != null;

  bool get suppressTaps => _suppressTaps || active;

  // ---- 输入 ----

  void pointerDown(int pointer, Offset position) {
    _pointers[pointer] = position;
    if (_pointers.length == 2) {
      _beginPinch(_midpoint(), _distance());
    } else if (_pointers.length > 2 && _base != null) {
      _rebase();
    }
  }

  void pointerMove(int pointer, Offset position) {
    if (!_pointers.containsKey(pointer)) return;
    _pointers[pointer] = position;
    final base = _base;
    if (base == null || _pointers.length < 2) return;
    final distance = _distance();
    if (distance > 0 && base > 0) _applyScale(distance / base);
  }

  void pointerUp(int pointer) {
    if (_pointers.remove(pointer) == null) return;
    if (_base != null) {
      if (_pointers.length < 2) {
        _endPinch();
      } else {
        _rebase();
      }
    }
    if (_pointers.isEmpty) scheduleMicrotask(_releaseIfIdle);
  }

  void panZoomStart(Offset focal) {
    final position = positionOf();
    if (position != null) _stopScrolling(position);
    _beginPinch(focal, 1);
  }

  void panZoomUpdate(double scale) {
    final base = _base;
    if (base != null && base > 0 && scale > 0) _applyScale(scale / base);
  }

  void panZoomEnd() {
    if (_base != null) _endPinch();
    scheduleMicrotask(_releaseIfIdle);
  }

  /// 桌面 Ctrl + 滚轮：以 [focal] 为焦点动画换到相邻一档（[zoomIn] 为放大，
  /// 即列数变少）。上一次还没走完时先走完，再从新档位换下一档。
  void step({required bool zoomIn, required Offset focal}) {
    final position = positionOf();
    if (_base != null || position == null || !position.hasContentDimensions) {
      return;
    }
    _finishSettle();
    final zoom = zoomOf();
    final target = zoomIn ? zoom.zoomedIn : zoom.zoomedOut;
    if (target == null) return;
    _stopScrolling(position);
    _focal = focal;
    frozen.value = true;
    _startMorph(zoom, position.pixels, target);
    _settleTo1();
  }

  /// 数据整体换了（换筛选）：放弃进行中的过渡，回到正式网格原样。
  void reset() {
    _settle.stop();
    _base = null;
    _endMorphs();
    scheduleMicrotask(_releaseIfIdle);
  }

  @override
  void dispose() {
    _disposed = true;
    _settle.dispose();
    _images?.dispose();
    morph.dispose();
    frozen.dispose();
    super.dispose();
  }

  // ---- 捏合 ----

  void _beginPinch(Offset focal, double base) {
    final position = positionOf();
    if (position == null || !position.hasContentDimensions || base <= 0) {
      return;
    }
    _finishSettle();
    _focal = focal;
    _base = base;
    _scale = 1;
    _suppressTaps = true;
    frozen.value = true;
  }

  /// 参与捏合的手指变了（第三根落下或抬起）：保持当前比例，换成新的
  /// 两指距离做基准，画面不跳。
  void _rebase() {
    final distance = _distance();
    if (distance > 0 && _scale > 0) _base = distance / _scale;
  }

  void _applyScale(double scale) {
    _scale = scale;
    final current = morph.value;
    final fromZoom = current?.from ?? zoomOf();
    final fromOffset = current?.fromOffset ?? positionOf()?.pixels ?? 0;
    if (current == null || (scale - 1).abs() >= _deadZone) {
      // 方向：缩小一档或放大一档；到头时终点就是起点（阻尼缩放）。
      final target =
          (scale < 1 ? fromZoom.zoomedOut : fromZoom.zoomedIn) ?? fromZoom;
      if (current == null || current.to != target) {
        _startMorph(fromZoom, fromOffset, target);
      }
    }
    final active = morph.value;
    if (active == null) return;
    if (active.rubberBand) {
      _progress = 0;
      _rubberScale = GalleryPinch.rubberBand(scale);
      notifyListeners();
      return;
    }
    final ratio = active.ratio;
    final progress = GalleryPinch.progress(scale, ratio);
    if (progress >= 1) {
      // 终点档已是原大：把它当成新起点，基准乘上格子比，接着走向下一档。
      unawaited(HapticFeedback.selectionClick());
      final base = _base;
      if (base != null) _base = base * ratio;
      final next =
          (scale < 1 ? active.to.zoomedOut : active.to.zoomedIn) ?? active.to;
      _startMorph(active.to, active.toOffset, next);
      _applyScale(scale / ratio);
      return;
    }
    _progress = progress;
    _rubberScale = 1;
    notifyListeners();
  }

  /// 开始一段从 [from]（滚动偏移 [fromOffset]）到 [to] 的过渡：按焦点下
  /// 那张图算出终点档的偏移，夹在终点档的滚动范围内。
  void _startMorph(GalleryZoom from, double fromOffset, GalleryZoom to) {
    final position = positionOf();
    if (position == null || !position.hasContentDimensions) return;
    final viewport = position.viewportDimension;
    final fromGrid = gridFor(from);
    final toGrid = gridFor(to);
    var toOffset = fromOffset;
    if (to != from) {
      final anchor = fromGrid.anchorAt(_focal.dx, fromOffset + _focal.dy);
      final maxOffset = math.max(
        0.0,
        toGrid.extent + trailingExtentOf() - viewport,
      );
      final offset = anchor == null
          ? 0.0
          : (toGrid.offsetForAnchor(anchor, _focal.dy) ?? 0.0);
      toOffset = offset.clamp(0.0, maxOffset);
    }
    final plan = GalleryMorphPlan(
      from: fromGrid,
      fromOffset: fromOffset,
      to: toGrid,
      toOffset: toOffset,
      viewportHeight: viewport,
    );
    final images = _images ??= GalleryMorphImages(
      liveImageOf: liveImageOf,
      configuration: imageConfigurationOf(),
      onChanged: notifyListeners,
    );
    for (var k = 0; k < plan.count; k++) {
      final index = plan.first + k;
      final source = sourceOf(index);
      images.request(index, source, providerFor(source, to));
    }
    _progress = 0;
    _rubberScale = 1;
    morph.value = GalleryMorph(
      plan: plan,
      from: from,
      to: to,
      fromOffset: fromOffset,
      toOffset: toOffset,
    );
  }

  void _endPinch() {
    _base = null;
    final current = morph.value;
    if (current == null) {
      scheduleMicrotask(_releaseIfIdle);
      return;
    }
    if (!current.rubberBand && _progress >= GalleryPinch.commitThreshold) {
      _settleTo1();
    } else {
      _settleBy(0);
    }
  }

  // ---- 弹簧收尾 ----

  void _settleTo1() => _settleBy(1);

  /// 进度弹到 [to]（0 回到起点档，1 到终点档）；阻尼缩放同时弹回原大。
  void _settleBy(double to) {
    _settleFrom = _progress;
    _settleTo = to;
    _rubberFrom = _rubberScale;
    final duration = settleDuration();
    if (duration == Duration.zero) {
      _completeSettle();
      return;
    }
    _settle
      ..duration = duration
      ..forward(from: 0);
  }

  void _handleSettleTick() {
    if (!_settle.isAnimating) return;
    final t = ExpressiveMotion.spatial.transform(_settle.value);
    _progress = _settleFrom + (_settleTo - _settleFrom) * t;
    _rubberScale = _rubberFrom + (1 - _rubberFrom) * t;
    notifyListeners();
  }

  void _handleSettleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _completeSettle();
  }

  /// 新的捏合 / 滚轮换档开始时，把还在走的弹簧直接走完。
  void _finishSettle() {
    if (!_settle.isAnimating) return;
    _settle.stop();
    _completeSettle();
  }

  /// 弹簧到点：落在终点档或起点档。与正式网格不同时改滚动位置并换档，
  /// 然后撤下画布。
  void _completeSettle() {
    if (_disposed) return;
    final current = morph.value;
    if (current != null) {
      final toEnd = _settleTo >= 1 && !current.rubberBand;
      final zoom = toEnd ? current.to : current.from;
      final offset = toEnd ? current.toOffset : current.fromOffset;
      final position = positionOf();
      if (zoom != zoomOf() || (position != null && position.pixels != offset)) {
        if (toEnd) unawaited(HapticFeedback.selectionClick());
        position?.correctPixels(offset);
        onCommit(zoom);
      }
    }
    _endMorphs();
    scheduleMicrotask(_releaseIfIdle);
  }

  void _endMorphs() {
    _progress = 0;
    _rubberScale = 1;
    morph.value = null;
    _images?.dispose();
    _images = null;
  }

  void _releaseIfIdle() {
    if (_disposed || _pointers.isNotEmpty || _base != null) return;
    if (_settle.isAnimating || morph.value != null) return;
    _suppressTaps = false;
    frozen.value = false;
  }

  /// 触控板与滚轮换档时列表可能还在惯性滚动：先停住，锚点才对得上。
  /// （触摸捏合不必：手指按下时列表的惯性就已停止。）
  void _stopScrolling(ScrollPosition position) {
    if (position.isScrollingNotifier.value && position.hasPixels) {
      position.jumpTo(position.pixels);
    }
  }

  // ---- 几何 ----

  List<Offset> get _pair => _pointers.values.take(2).toList(growable: false);

  Offset _midpoint() {
    final pair = _pair;
    return (pair[0] + pair[1]) / 2;
  }

  double _distance() {
    if (_pointers.length < 2) return 0;
    final pair = _pair;
    return (pair[1] - pair[0]).distance;
  }
}
