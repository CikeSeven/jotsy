import 'dart:ui' as ui show Image;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 容器转场途中，下层页面（来源卡片所在的列表页）改画一张快照。
///
/// 为什么要快照：转场途中下层页面完全静止（只盖一层遮罩），却仍要逐帧重新
/// 光栅化——首页满屏玻璃卡片的背景模糊、动图封面，一帧就要 8ms 上下，在
/// 120Hz 下光凭它就吃满预算。改画快照后每帧只剩一张贴图。
///
/// 为什么不用 SDK 的 `SnapshotWidget`：它把子树画进一棵没挂上主树的临时
/// 图层树再截图。内容玻璃的预模糊取样（`GlassBackdropSampleView`）是跟随
/// 页面背景 Leader 的 `CompositedTransformFollower`，Leader 不在挂载的树上
/// 时整个不画（`showWhenUnlinked: false`）——快照里的玻璃卡片只剩半透明
/// 底色，背景透得更清楚，转场途中其他卡片像是一起变透明了。这里拍照的
/// 临时图层一律先挂进挂载着的图层树（与首页景深切页
/// `RenderHomeTabDepth._capture` 同一做法），Leader 与 Follower 照常链接，
/// 截到的与屏上逐像素一致：
/// - 下层页面上一帧就在屏上（推入时）：所在的重绘边界图层仍挂在树上，
///   临时图层就地挂进去；
/// - 下层页面上一帧不在屏上（停稳后返回：路由的重绘边界图层已脱离树）：
///   临时图层改挂到根图层上截图，截完立即摘下。
/// 两种都拍不了（含平台视图、找不到挂载的根）时这一帧照常实时绘制；前者
/// 之后一直实时绘制，后者下一帧再拍。
///
/// 输入：开关 [ContainerTransformBelowSnapshotController]；输出：开启后的第
/// 一次绘制拍下子树并改画位图，关闭后释放位图、恢复实时绘制。布局、点按与
/// 读屏始终是子树自己的（返回时量卡片位置只靠布局）。卡片转场先隐藏原卡片
/// 再开启本快照，快照里原卡片的位置留空（只画背景）、其余玻璃卡片照常保留。
class ContainerTransformBelowSnapshotController extends ChangeNotifier {
  bool _enabled = false;

  /// 是否画快照。从关到开会在下一次绘制时重拍。
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
  }
}

/// 见 [ContainerTransformBelowSnapshotController]。
class ContainerTransformBelowSnapshot extends SingleChildRenderObjectWidget {
  const ContainerTransformBelowSnapshot({
    super.key,
    required this.controller,
    required super.child,
  });

  final ContainerTransformBelowSnapshotController controller;

  @override
  RenderContainerTransformBelowSnapshot createRenderObject(
    BuildContext context,
  ) {
    return RenderContainerTransformBelowSnapshot(
      controller: controller,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderContainerTransformBelowSnapshot renderObject,
  ) {
    renderObject
      ..controller = controller
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class RenderContainerTransformBelowSnapshot extends RenderProxyBox {
  RenderContainerTransformBelowSnapshot({
    required this._controller,
    required this._devicePixelRatio,
  });

  ContainerTransformBelowSnapshotController _controller;
  set controller(ContainerTransformBelowSnapshotController value) {
    if (identical(value, _controller)) return;
    if (attached) {
      _controller.removeListener(_changed);
      value.addListener(_changed);
    }
    _releaseImage();
    _controller = value;
    _changed();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    _releaseImage();
    markNeedsPaint();
  }

  ui.Image? _image;
  Size? _imageSize;

  /// 子树含平台视图等无法截图的内容：本次开启期间一直实时绘制。
  bool _unsupported = false;

  /// 已安排“下一帧再拍”，避免同一帧重复登记。
  bool _retryScheduled = false;

  /// 测试用：此刻画的快照（实时绘制时为 null）。
  @visibleForTesting
  ui.Image? get debugImage => _image;

  // 拍照时临时图层挂进当前图层树，祖先需要按合成方式处理裁切等效果。
  @override
  bool get alwaysNeedsCompositing => true;

  void _changed() {
    if (!_controller.enabled) {
      _releaseImage();
      _unsupported = false;
    }
    markNeedsPaint();
  }

  void _releaseImage() {
    final image = _image;
    if (image == null) return;
    image.dispose();
    _image = null;
    _imageSize = null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(_changed);
  }

  @override
  void detach() {
    _controller.removeListener(_changed);
    super.detach();
  }

  @override
  void dispose() {
    _releaseImage();
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (!_controller.enabled || _unsupported) {
      _releaseImage();
      context.paintChild(child, offset);
      return;
    }
    if (_image != null && _imageSize != size) {
      _releaseImage();
    }
    final image = _image ?? _capture(context, offset, child);
    if (image == null) {
      // 这一帧已在 [_capture] 里实时画过。
      return;
    }
    context.canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      offset & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  /// 把子树画进一个临时图层，挂在挂载着的树上截图（见类注释）。成功时摘下
  /// 临时图层、返回快照；拍不了时临时图层留在原处，就是这一帧的实时绘制。
  ui.Image? _capture(PaintingContext context, Offset offset, RenderBox child) {
    final layer = OffsetLayer(offset: offset);
    context.pushLayer(
      layer,
      (PaintingContext context, Offset offset) =>
          context.paintChild(child, offset),
      Offset.zero,
    );
    if (!layer.supportsRasterization()) {
      _unsupported = true;
      return null;
    }
    final root = layer.attached ? null : _attachedRootLayer();
    if (!layer.attached && root == null) {
      _scheduleRetry();
      return null;
    }
    // 移动期间由这里持有：没有父图层也没有句柄的图层会被立即释放。
    final handle = LayerHandle<OffsetLayer>(layer);
    try {
      if (root != null) {
        // 摘下后挂到根图层上：截的只是临时图层自己，根图层的变换不参与。
        layer.remove();
        root.append(layer);
      }
      final image = layer.toImageSync(
        Offset.zero & size,
        pixelRatio: _devicePixelRatio,
      );
      _image = image;
      _imageSize = size;
      return image;
    } catch (error) {
      debugPrint('Snapshotting the page below the transition failed: $error');
      _unsupported = true;
      return null;
    } finally {
      // 摘下并释放临时图层；子树里各重绘边界的图层由各自的渲染对象持有，
      // 恢复实时绘制时再挂回来。
      layer.remove();
      handle.layer = null;
      if (_image == null) {
        // 拍照失败：这一帧仍要画出下层。
        context.paintChild(child, offset);
      }
    }
  }

  /// 渲染树根（RenderView）的图层：它总挂在树上。
  ContainerLayer? _attachedRootLayer() {
    RenderObject node = this;
    while (node.parent != null) {
      node = node.parent!;
    }
    // 根图层只有渲染对象自己能拿到；这里只是临时挂一个子图层、同步截完
    // 就摘下，不改动它的其他内容。
    // ignore: invalid_use_of_protected_member
    final root = node.layer;
    return root != null && root.attached ? root : null;
  }

  void _scheduleRetry() {
    if (_retryScheduled) return;
    _retryScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _retryScheduled = false;
      if (attached && _controller.enabled && _image == null) {
        markNeedsPaint();
      }
    });
  }
}
