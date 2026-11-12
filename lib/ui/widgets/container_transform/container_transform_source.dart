import 'dart:ui' as ui show Image;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import 'container_transform_source_visibility.dart';

/// 容器展开（卡片 ↔ 整页）的来源端：登记卡片、在点按时量出它在屏上的位置
/// 并截下画面，返回时按同一标签找回它。
///
/// 输入：标签 [ContainerTransformSource.tag]（如日记卡片按日记 id）、卡片的
/// 圆角；输出：[ContainerTransformOrigin]（点按时）与 [ContainerTransformShot]
/// （返回时，经 [locateContainerTransformSource]）。画面是 GPU 上的 `ui.Image`，
/// 所有权随对象转交；路由持有 [ContainerTransformShot.holdSource] 时，来源
/// 卡片保留布局但停止绘制，归位时恢复，避免飞行画面与原卡片同时显示。
///
/// 画面截的是卡片所在页面的整层（路由最外层的 RepaintBoundary），再裁出
/// 卡片那一块，而不是只画卡片自己：玻璃卡片的模糊要读页面背景，单独截卡片
/// 只剩半透明的底色，起飞那一帧就会和屏上的卡片对不上。裁出来的一块连同
/// 卡片背后的背景是整块不透明的，盖在原卡片上分毫不差。
///
/// 系统开启“减少动态效果”或平台不用容器展开（[AppPlatform.supportsContainerTransform]）
/// 时 [ContainerTransformSource.capture] 返回 null，调用方按普通路由打开。
class ContainerTransformSource extends StatefulWidget {
  const ContainerTransformSource({
    super.key,
    required this.tag,
    required this.borderRadius,
    required this.child,
  });

  /// 来源的标识：返回时按它找回卡片（翻页翻到别的日记时换成那一篇的）。
  final Object tag;

  /// 卡片的圆角：展开起点与收回终点的圆角。
  final double borderRadius;

  final Widget child;

  /// 点按时调用：[context] 必须在来源之内（卡片里点按处的 context）。
  ///
  /// 卡片还没布局、找不到页面层或截图失败时返回 null。
  static ContainerTransformOrigin? capture(BuildContext context) {
    if (!AppPlatform.supportsContainerTransform ||
        ExpressiveMotion.reduceMotion(context)) {
      return null;
    }
    final state = context
        .findAncestorStateOfType<_ContainerTransformSourceState>();
    if (state == null) {
      return null;
    }
    final route = state._route;
    final shot = state._shoot();
    if (route == null || shot == null) {
      return null;
    }
    return ContainerTransformOrigin._(
      tag: state.widget.tag,
      route: route,
      shot: shot,
    );
  }

  @override
  State<ContainerTransformSource> createState() =>
      _ContainerTransformSourceState();
}

/// 按 [tag] 找回 [route] 里仍挂在树上、露在屏上的来源，量出位置并截图。
///
/// 返回时在下层页面重新布局之后调用（见 `ContainerTransformPageRoute`）：
/// 卡片可能因为改了内容而换了位置或样子，截的是这一刻的画面。来源已卸载、
/// 不在 [route] 里（同一篇日记也可能出现在更下层的列表里）、或几乎不在屏上
/// 时返回 null，调用方改为原地淡出。
ContainerTransformShot? locateContainerTransformSource(
  Object tag, {
  required ModalRoute<Object?> route,
}) {
  final candidates = _ContainerTransformSourceState._registry[tag];
  if (candidates == null) {
    return null;
  }
  for (final state in candidates) {
    if (!state.mounted || !identical(state._route, route)) {
      continue;
    }
    final shot = state._shoot(requireVisible: true);
    if (shot != null) {
      return shot;
    }
  }
  return null;
}

/// 点按时记下的展开起点：来源所在的路由、标签与那一刻的 [ContainerTransformShot]。
///
/// 交给路由后由路由接管画面；没有交出去（如入口在等待途中被卸载）时调用方
/// 调用 [dispose] 释放。
class ContainerTransformOrigin {
  ContainerTransformOrigin._({
    required this.tag,
    required this.route,
    required ContainerTransformShot this._shot,
  });

  final Object tag;

  /// 来源所在的路由：返回时只在这个路由里找卡片。
  final ModalRoute<Object?> route;

  ContainerTransformShot? _shot;

  /// 取走起点（所有权转给调用方）；只能取一次，之后为 null。
  ContainerTransformShot? takeShot() {
    final shot = _shot;
    _shot = null;
    return shot;
  }

  void dispose() {
    _shot?.dispose();
    _shot = null;
  }
}

/// 某一刻来源卡片在导航器坐标系里的位置、圆角与画面。
///
/// [image] 覆盖导航器坐标系里的 [imageRect]（卡片露在页面里的部分，卡片一
/// 部分滑出屏幕时比 [rect] 小）。
class ContainerTransformShot {
  ContainerTransformShot({
    required this.rect,
    required this.radius,
    required this.image,
    required this.imageRect,
    this.holdSource,
  });

  final Rect rect;
  final double radius;
  final ui.Image image;
  final Rect imageRect;

  /// 截图完成且飞行画面能够接替来源时由路由调用，返回幂等的恢复句柄。
  /// 不能在截图前隐藏，否则玻璃卡片的整页截图只会剩下背景。
  final ValueGetter<VoidCallback>? holdSource;

  void dispose() => image.dispose();
}

class _ContainerTransformSourceState extends State<ContainerTransformSource> {
  /// 全部挂在树上的来源，按标签分组。同一标签可能同时出现在几层路由里（首页
  /// 列表与搜索结果里的同一篇），查找时再按路由筛。
  static final Map<Object, Set<_ContainerTransformSourceState>> _registry =
      <Object, Set<_ContainerTransformSourceState>>{};

  /// 露在屏上的高度至少这么多才算“看得见”，否则收回到一条细缝里不如淡出。
  static const double _minVisibleExtent = 24;

  ModalRoute<Object?>? _route;
  final _visibility = ContainerTransformSourceVisibility();

  @override
  void initState() {
    super.initState();
    _register(widget.tag);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(ContainerTransformSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) {
      _unregister(oldWidget.tag);
      _register(widget.tag);
    }
  }

  @override
  void dispose() {
    _unregister(widget.tag);
    _visibility.dispose();
    super.dispose();
  }

  void _register(Object tag) {
    _registry
        .putIfAbsent(tag, () => <_ContainerTransformSourceState>{})
        .add(this);
  }

  void _unregister(Object tag) {
    final set = _registry[tag];
    if (set == null) {
      return;
    }
    set.remove(this);
    if (set.isEmpty) {
      _registry.remove(tag);
    }
  }

  /// 量出卡片在导航器里的位置，并从页面层裁出它的画面。
  ///
  /// [requireVisible] 时卡片露在导航器里的部分太少（滑出屏幕、只在列表的
  /// 预构建区里）返回 null。
  ContainerTransformShot? _shoot({bool requireVisible = false}) {
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
        (requireVisible &&
            visible.height <
                _minVisibleExtent.clamp(0, rect.height).toDouble())) {
      return null;
    }

    // 卡片所在路由最外层的重绘边界：页面背景、玻璃模糊都在它的图层里。
    RenderObject? boundary;
    RenderObject? node = box;
    while (node != null && !identical(node, navigatorBox)) {
      if (node.isRepaintBoundary) {
        boundary = node;
      }
      node = node.parent;
    }
    if (boundary is! RenderBox || !boundary.hasSize) {
      return null;
    }
    // 重绘边界的图层只有子类能拿到；这里只读、在两帧之间同步截图，图层
    // 内容就是上一帧画到屏上的样子。
    // ignore: invalid_use_of_protected_member
    final layer = boundary.layer;
    if (layer is! OffsetLayer) {
      return null;
    }
    final inBoundary = MatrixUtils.transformRect(
      box.getTransformTo(boundary),
      Offset.zero & box.size,
    ).intersect(Offset.zero & boundary.size);
    if (inBoundary.isEmpty) {
      return null;
    }
    final imageRect = MatrixUtils.transformRect(
      boundary.getTransformTo(navigatorBox),
      inBoundary,
    );
    final ui.Image image;
    try {
      image = layer.toImageSync(
        inBoundary,
        pixelRatio: View.of(context).devicePixelRatio,
      );
    } catch (error) {
      debugPrint('Capturing the container transform source failed: $error');
      return null;
    }
    return ContainerTransformShot(
      rect: rect,
      radius: widget.borderRadius,
      image: image,
      imageRect: imageRect,
      holdSource: _visibility.hold,
    );
  }

  @override
  Widget build(BuildContext context) => ContainerTransformSourcePaintGate(
    visibility: _visibility,
    child: widget.child,
  );
}
