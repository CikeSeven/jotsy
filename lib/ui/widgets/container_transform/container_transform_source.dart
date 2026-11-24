import 'dart:ui' as ui show Image;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import 'container_transform_source_visibility.dart';
import 'morph_landing.dart';

/// 容器展开（卡片 ↔ 整页）的来源端：登记卡片、在点按时量出它在屏上的位置，
/// 转场起步与返回时按同一标签找回它、截下画面并暂停原卡片绘制。
///
/// 输入：标签 [ContainerTransformSource.tag]（如日记卡片按日记 id）、卡片的
/// 圆角；输出：[ContainerTransformOrigin]（点按时，仅含位置与圆角，不持有
/// GPU 资源）与 [ContainerTransformShot]（转场时，经
/// [locateContainerTransformSource]，带卡片画面与隐藏句柄）。路由持有
/// [ContainerTransformShot.holdSource] 期间，来源卡片保留布局但停止绘制，
/// 停稳、归位或提前移除时当帧恢复——展开 / 收回途中容器移开、露出原位置时，
/// 列表里不会再有一张原卡片。
///
/// 画面截的是卡片所在路由最外层重绘边界里卡片那一块，而不是只画卡片自己：
/// 玻璃或半透明卡片依赖背后的页面背景与预模糊取样，整层裁出的一块连同背后
/// 背景一起是不透明的，盖在原卡片上分毫不差，且只光栅化卡片大小。
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
  /// 卡片还没布局或不在屏上时返回 null。
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
    final bounds = state._measure();
    if (route == null || bounds == null) {
      return null;
    }
    return ContainerTransformOrigin._(
      tag: state.widget.tag,
      route: route,
      bounds: bounds,
    );
  }

  @override
  State<ContainerTransformSource> createState() =>
      _ContainerTransformSourceState();
}

/// 按 [tag] 找回 [route] 里仍挂在树上、露在屏上的来源，量出位置并截下画面。
///
/// 推入首帧末（[requireVisible] 为 false，点按的那张即使只露出一小截也照常
/// 展开）或返回时下层页面重新排版绘制之后（[requireVisible] 为 true）调用：
/// 卡片可能因为改了内容而换了位置或样子。来源已卸载、不在 [route] 里（同一
/// 篇日记也可能出现在更下层的列表里）、或露出的部分太少时返回 null。
/// 返回的 [ContainerTransformShot] 若带 `image`，所有权归调用方。
ContainerTransformShot? locateContainerTransformSource(
  Object tag, {
  required ModalRoute<Object?> route,
  bool requireVisible = true,
}) {
  final candidates = _ContainerTransformSourceState._registry[tag];
  if (candidates == null) {
    return null;
  }
  for (final state in candidates) {
    if (!state.mounted || !identical(state._route, route)) {
      continue;
    }
    final shot = state._shoot(requireVisible: requireVisible);
    if (shot != null) {
      return shot;
    }
  }
  return null;
}

/// 点按时记下的展开起点：来源所在的路由、标签与那一刻的位置。
class ContainerTransformOrigin {
  const ContainerTransformOrigin._({
    required this.tag,
    required this.route,
    required this.bounds,
  });

  final Object tag;

  /// 来源所在的路由：返回时只在这个路由里找卡片。
  final ModalRoute<Object?> route;

  final ContainerTransformBounds bounds;
}

/// 某一刻来源卡片在导航器坐标系里的位置与圆角。
@immutable
class ContainerTransformBounds {
  const ContainerTransformBounds({required this.rect, required this.radius});

  final Rect rect;
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is ContainerTransformBounds &&
      other.rect == rect &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(rect, radius);
}

/// 某一刻来源卡片在导航器坐标系里的位置、圆角、画面与绘制占用句柄。
///
/// [image] 覆盖导航器坐标系里的 [imageRect]（卡片露在页面里的部分，卡片一
/// 部分滑出屏幕时比 [rect] 小）；截图失败（如含平台视图）时两者为 null，
/// 容器仍从 [rect] 展开 / 收回并照常隐藏原卡片。
class ContainerTransformShot {
  ContainerTransformShot({
    required this.rect,
    required this.radius,
    this.image,
    this.imageRect,
    this.holdSource,
  });

  ContainerTransformShot.fromBounds(ContainerTransformBounds bounds)
    : rect = bounds.rect,
      radius = bounds.radius,
      image = null,
      imageRect = null,
      holdSource = null;

  final Rect rect;
  final double radius;
  final ui.Image? image;
  final Rect? imageRect;

  /// 截图完成且容器能够接替来源时由路由调用，返回幂等的恢复句柄。不能在
  /// 截图前隐藏，否则整页层里卡片那一块只剩背景。
  final ValueGetter<VoidCallback>? holdSource;

  ContainerTransformBounds get bounds =>
      ContainerTransformBounds(rect: rect, radius: radius);

  void dispose() => image?.dispose();
}

class _ContainerTransformSourceState extends State<ContainerTransformSource> {
  /// 全部挂在树上的来源，按标签分组。同一标签可能同时出现在几层路由里（首页
  /// 列表与搜索结果里的同一篇），查找时再按路由筛。
  static final Map<Object, Set<_ContainerTransformSourceState>> _registry =
      <Object, Set<_ContainerTransformSourceState>>{};

  /// 露在屏上的高度至少这么多才算“看得见”，否则收回到一条细缝里不如原地
  /// 退场。
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

  /// 量出卡片在导航器里的位置（只靠布局结果，不需要卡片这一帧画在屏上）。
  ContainerTransformBounds? _measure({bool requireVisible = false}) {
    final rect = measureInNavigator(
      context,
      minVisibleExtent: requireVisible ? _minVisibleExtent : 0,
    );
    return rect == null
        ? null
        : ContainerTransformBounds(rect: rect, radius: widget.borderRadius);
  }

  /// 量出卡片在导航器里的位置，并从所在路由最外层重绘边界裁出它的画面。
  ///
  /// [requireVisible] 时卡片露在导航器里的部分太少（滑出屏幕、只在列表的
  /// 预构建区里）返回 null。截图失败时仍返回位置与隐藏句柄（`image` 为
  /// null），容器照常展开并隐藏原卡片。
  ContainerTransformShot? _shoot({required bool requireVisible}) {
    final rect = measureInNavigator(
      context,
      minVisibleExtent: requireVisible ? _minVisibleExtent : 0,
    );
    if (rect == null) {
      return null;
    }
    ui.Image? image;
    Rect? imageRect;
    final box = context.findRenderObject();
    final navigatorBox = Navigator.maybeOf(context)?.context.findRenderObject();
    if (box is RenderBox &&
        navigatorBox is RenderBox &&
        box.attached &&
        navigatorBox.attached) {
      // 卡片所在路由最外层的重绘边界：页面背景、玻璃预模糊取样与实时模糊都在
      // 它的图层里，且此时已挂在渲染树上。
      RenderObject? boundary;
      RenderObject? node = box;
      while (node != null && !identical(node, navigatorBox)) {
        if (node.isRepaintBoundary) {
          boundary = node;
        }
        node = node.parent;
      }
      if (boundary is RenderBox && boundary.hasSize) {
        // 重绘边界的图层只有子类能拿到；这里只读、在两帧之间同步截图，图层
        // 内容就是上一帧画到屏上的样子。
        // ignore: invalid_use_of_protected_member
        final layer = boundary.layer;
        if (layer is OffsetLayer &&
            layer.attached &&
            layer.supportsRasterization()) {
          final inBoundary = MatrixUtils.transformRect(
            box.getTransformTo(boundary),
            Offset.zero & box.size,
          ).intersect(Offset.zero & boundary.size);
          if (!inBoundary.isEmpty) {
            final pixelRatio =
                MediaQuery.maybeDevicePixelRatioOf(context) ??
                View.of(context).devicePixelRatio;
            try {
              image = layer.toImageSync(inBoundary, pixelRatio: pixelRatio);
              imageRect = MatrixUtils.transformRect(
                boundary.getTransformTo(navigatorBox),
                inBoundary,
              );
            } catch (error) {
              debugPrint(
                'Capturing the container transform source failed: $error',
              );
            }
          }
        }
      }
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
