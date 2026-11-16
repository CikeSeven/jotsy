import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import '../models/gallery_grid.dart';
import '../models/gallery_level.dart';
import '../models/gallery_pinch.dart';

/// 捏合途中两层的画法：都以 [focal] 为原点缩放；[scale] / [opacity] /
/// [shift] 为当前档（正式网格），[previewScale] / [previewOpacity] /
/// [previewShift] 为目标档预览。shift 为该层内容在缩放前的竖向平移
/// （见 [GalleryZoomPreview.drift]）。
@immutable
class GalleryZoomFrame {
  const GalleryZoomFrame({
    required this.focal,
    this.scale = 1,
    this.opacity = 1,
    this.shift = 0,
    this.previewScale = 1,
    this.previewOpacity = 0,
    this.previewShift = 0,
  });

  static const GalleryZoomFrame identity = GalleryZoomFrame(focal: Offset.zero);

  final Offset focal;
  final double scale;
  final double opacity;
  final double shift;
  final double previewScale;
  final double previewOpacity;
  final double previewShift;
}

/// 捏合途中目标档的预览：布局 [grid]、停在滚动偏移 [offset]（让手指下
/// 那张图与当前档里同一张图对齐，换档时正式网格直接跳到这里），[ratio]
/// 为目标档与当前档的格子边长比。[controller] 只给预览那个不可滚动的
/// 滚动视图定位用，由驱动在预览撤下后释放。
class GalleryZoomPreview {
  GalleryZoomPreview({
    required this.zoom,
    required this.grid,
    required this.offset,
    required this.ratio,
    this.drift = 0,
  }) : controller = ScrollController(initialScrollOffset: offset);

  final GalleryZoom zoom;
  final GalleryGrid grid;
  final double offset;
  final double ratio;

  /// 对齐所需的偏移超出了目标档的滚动范围（列表顶部或底部附近）时，被夹
  /// 掉的那一段（夹后 − 夹前）。进度为 p 时预览平移 `drift × (1 − p)`、
  /// 正式网格平移 `−drift × p / ratio`（换成同一屏幕距离）：两层始终一起
  /// 移动、锚点对齐，进度到 1 时预览正好落在夹后的位置，与换档后的正式
  /// 网格一致，列表顺势贴住顶 / 底。
  final double drift;
  final ScrollController controller;
}

/// 媒体画廊的捏合换档驱动：输入指针 / 触控板 / Ctrl + 滚轮，输出逐帧的
/// [frame]、目标档预览（经 [onPreviewChanged]）与换档（经 [onCommit]）。
///
/// 状态与时机：
/// - 两根手指落下开始一次捏合（焦点取两指中点，此后不动）；手指比例
///   < 1 预览缩小一档、> 1 预览放大一档，两层随进度交叉淡入（见
///   [GalleryPinch]）；没有下一档时只做阻尼缩放。
/// - 进度到 1（目标档已是原大）立即换档，并把比例的基准乘上格子比，手指
///   继续捏就接着走向再下一档：一次手势可以连跨几档，画面始终连续。
/// - 手指少于两根时松手：进度过 [GalleryPinch.commitThreshold] 就用弹簧
///   走完并换档，否则弹回当前档。弹簧途中不改目标档（过冲越过 1 不会
///   反向预览另一档）；新的捏合开始时先把它直接走完。
/// - 换档：先把正式网格的滚动位置改成预览的偏移（`correctPixels`，不触发
///   滚动、下一帧按新布局生效），再通知宿主换档位，同一帧里正式网格与
///   预览逐像素一致，预览随即撤下。
/// - [frozen]：捏合与弹簧期间为 true，宿主的滚动物理据此吞掉拖动与惯性，
///   列表不跟着两根手指上下走；手指全部抬起、弹簧结束后才解除（放在
///   微任务里：抬起的那次事件随后才轮到列表的拖动结束，不能让它甩出惯性）。
/// - [suppressTaps]：本轮按下过两根手指时，抬起时的点按 / 长按不算数。
class GalleryZoomDriver {
  GalleryZoomDriver({
    required TickerProvider vsync,
    required this.zoomOf,
    required this.gridFor,
    required this.positionOf,
    required this.trailingExtentOf,
    required this.settleDuration,
    required this.onPreviewChanged,
    required this.onCommit,
  }) {
    _settle = AnimationController(vsync: vsync)
      ..addListener(_handleSettleTick)
      ..addStatusListener(_handleSettleStatus);
  }

  final GalleryZoom Function() zoomOf;
  final GalleryGrid Function(GalleryZoom zoom) gridFor;
  final ScrollPosition? Function() positionOf;

  /// 网格下方还有多高的内容（页脚），预览的滚动范围要算上它。
  final double Function() trailingExtentOf;

  /// 松手后弹簧收尾的时长（宿主经 `ExpressiveMotion.duration` 解析；减少
  /// 动画时为 0，直接落到终点）。
  final Duration Function() settleDuration;
  final ValueChanged<GalleryZoomPreview?> onPreviewChanged;
  final ValueChanged<GalleryZoom> onCommit;

  final ValueNotifier<GalleryZoomFrame> frame = ValueNotifier(
    GalleryZoomFrame.identity,
  );
  final ValueNotifier<bool> frozen = ValueNotifier<bool>(false);

  late final AnimationController _settle;
  final Map<int, Offset> _pointers = <int, Offset>{};

  /// 手指比例离 1 不到这么多时不选目标档。
  static const double _deadZone = 0.02;

  GalleryZoomPreview? _preview;
  Offset _focal = Offset.zero;

  /// 手指比例的基准：触摸为两指距离，触控板为事件的累计比例。为 null 表示
  /// 不在捏合中。
  double? _base;
  double _scale = 1;
  double _settleFrom = 1;
  double _settleTo = 1;
  bool _settleCommits = false;
  bool _suppressTaps = false;
  bool _disposed = false;

  GalleryZoomPreview? get preview => _preview;

  /// 是否正在捏合或弹簧收尾（宿主据此停用快速滚动条）。
  bool get active => _base != null || _settle.isAnimating || _preview != null;

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
    if (_pointers.isEmpty) {
      scheduleMicrotask(_releaseIfIdle);
    }
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
    if (_base != null || position == null) return;
    _finishSettle();
    final zoom = zoomOf();
    final target = zoomIn ? zoom.zoomedIn : zoom.zoomedOut;
    if (target == null) return;
    _stopScrolling(position);
    _focal = focal;
    _scale = 1;
    frozen.value = true;
    _setPreview(target);
    final preview = _preview;
    if (preview == null) return;
    _settleBy(preview.ratio, commit: true);
  }

  /// 数据整体换了（换筛选）：放弃进行中的捏合，回到当前档原样。
  void reset() {
    _settle.stop();
    _base = null;
    _scale = 1;
    _setPreview(null);
    frame.value = GalleryZoomFrame.identity;
    scheduleMicrotask(_releaseIfIdle);
  }

  void dispose() {
    _disposed = true;
    _settle.dispose();
    frame.dispose();
    frozen.dispose();
    final preview = _preview;
    if (preview != null) {
      // 预览的滚动视图与宿主同一帧卸载，之后再释放控制器。
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => preview.controller.dispose(),
      );
    }
  }

  // ---- 捏合 ----

  void _beginPinch(Offset focal, double base) {
    if (positionOf() == null || base <= 0) return;
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

  void _endPinch() {
    _base = null;
    final preview = _preview;
    if (preview == null) {
      _settleBy(1, commit: false);
      return;
    }
    final progress = GalleryPinch.progress(_scale, preview.ratio);
    if (progress >= GalleryPinch.commitThreshold) {
      _settleBy(preview.ratio, commit: true);
    } else {
      _settleBy(1, commit: false);
    }
  }

  /// 手指比例为 [scale] 时的画面；[settling] 为 true 表示弹簧途中，此时
  /// 不换目标档也不换档（终点由弹簧结束时处理）。
  void _applyScale(double scale, {bool settling = false}) {
    _scale = scale;
    if (!settling) {
      // 比例在 1 附近的死区里沿用已有的预览：手指抖动不会让预览在放大 /
      // 缩小两档之间来回重建。
      final zoom = zoomOf();
      final target = (scale - 1).abs() < _deadZone
          ? _preview?.zoom
          : scale < 1
          ? zoom.zoomedOut
          : zoom.zoomedIn;
      if (target != _preview?.zoom) _setPreview(target);
    }
    final preview = _preview;
    if (preview == null) {
      frame.value = GalleryZoomFrame(
        focal: _focal,
        scale: GalleryPinch.rubberBand(scale),
      );
      return;
    }
    final progress = GalleryPinch.progress(scale, preview.ratio);
    if (!settling && progress >= 1) {
      // 目标档已是原大：换档，基准乘上格子比，手指继续捏走向再下一档。
      final ratio = preview.ratio;
      _commit();
      final base = _base;
      if (base != null) _base = base * ratio;
      _applyScale(scale / ratio);
      return;
    }
    final fade = GalleryPinch.fade(progress);
    frame.value = GalleryZoomFrame(
      focal: _focal,
      scale: scale,
      opacity: 1 - fade,
      shift: preview.ratio > 0 ? -preview.drift * progress / preview.ratio : 0,
      previewScale: scale / preview.ratio,
      previewOpacity: fade,
      previewShift: preview.drift * (1 - progress),
    );
  }

  /// 换上 [target] 档的预览（null 为撤下）：按焦点下那张图算出它在目标档
  /// 里的滚动偏移，夹在目标档的滚动范围内。
  void _setPreview(GalleryZoom? target) {
    final old = _preview;
    GalleryZoomPreview? next;
    final position = positionOf();
    if (target != null && position != null && position.hasContentDimensions) {
      final current = gridFor(zoomOf());
      final grid = gridFor(target);
      final anchor = current.anchorAt(_focal.dx, position.pixels + _focal.dy);
      final maxOffset = math.max(
        0.0,
        grid.extent + trailingExtentOf() - position.viewportDimension,
      );
      final offset = anchor == null
          ? 0.0
          : (grid.offsetForAnchor(anchor, _focal.dy) ?? 0.0);
      final clamped = offset.clamp(0.0, maxOffset);
      next = GalleryZoomPreview(
        zoom: target,
        grid: grid,
        offset: clamped,
        drift: clamped - offset,
        ratio: current.cellExtent > 0
            ? grid.cellExtent / current.cellExtent
            : 1,
      );
    }
    if (old == null && next == null) return;
    _preview = next;
    onPreviewChanged(next);
    if (old != null) {
      // 预览的滚动视图在下一帧才卸载，之后再释放它的控制器。
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => old.controller.dispose(),
      );
    }
  }

  void _commit() {
    final preview = _preview;
    if (preview == null) return;
    unawaited(HapticFeedback.selectionClick());
    positionOf()?.correctPixels(preview.offset);
    onCommit(preview.zoom);
    _setPreview(null);
    _scale = 1;
    frame.value = GalleryZoomFrame(focal: _focal);
  }

  // ---- 弹簧收尾 ----

  void _settleBy(double to, {required bool commit}) {
    _settleFrom = _scale;
    _settleTo = to;
    _settleCommits = commit;
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
    _applyScale(
      GalleryPinch.lerpScale(_settleFrom, _settleTo, t),
      settling: true,
    );
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

  void _completeSettle() {
    if (_disposed) return;
    if (_settleCommits) {
      _commit();
    } else {
      _scale = 1;
      _setPreview(null);
      frame.value = GalleryZoomFrame(focal: _focal);
    }
    _settleCommits = false;
    scheduleMicrotask(_releaseIfIdle);
  }

  void _releaseIfIdle() {
    if (_disposed || _pointers.isNotEmpty || _base != null) return;
    if (_settle.isAnimating) return;
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
