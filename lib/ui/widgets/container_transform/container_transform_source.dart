import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import 'morph_landing.dart';

/// 容器展开（卡片 ↔ 整页）的来源端：登记卡片、在点按时量出它在屏上的位置，
/// 返回时按同一标签找回它。
///
/// 输入：标签 [ContainerTransformSource.tag]（如日记卡片按日记 id）、卡片的
/// 圆角；输出：[ContainerTransformOrigin]（点按时）与 [ContainerTransformBounds]
/// （返回时，经 [locateContainerTransformSource]）。只量位置与圆角，不截图、
/// 也不隐藏卡片：容器全程不透明，起点与终点恰好盖住卡片（见
/// `ContainerTransformTransition`）。
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

/// 按 [tag] 找回 [route] 里仍挂在树上、露在屏上的来源，量出位置。
///
/// 返回时在下层页面重新布局之后调用（见 `ContainerTransformPageRoute`）：
/// 卡片可能因为改了内容而换了位置或大小。来源已卸载、不在 [route] 里（同一
/// 篇日记也可能出现在更下层的列表里）、或几乎不在屏上时返回 null，调用方
/// 改为原地退场。
ContainerTransformBounds? locateContainerTransformSource(
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
    final bounds = state._measure(requireVisible: true);
    if (bounds != null) {
      return bounds;
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

class _ContainerTransformSourceState extends State<ContainerTransformSource> {
  /// 全部挂在树上的来源，按标签分组。同一标签可能同时出现在几层路由里（首页
  /// 列表与搜索结果里的同一篇），查找时再按路由筛。
  static final Map<Object, Set<_ContainerTransformSourceState>> _registry =
      <Object, Set<_ContainerTransformSourceState>>{};

  /// 露在屏上的高度至少这么多才算“看得见”，否则收回到一条细缝里不如原地
  /// 退场。
  static const double _minVisibleExtent = 24;

  ModalRoute<Object?>? _route;

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
  ///
  /// [requireVisible] 时卡片露在导航器里的部分太少（滑出屏幕、只在列表的
  /// 预构建区里）返回 null。
  ContainerTransformBounds? _measure({bool requireVisible = false}) {
    final rect = measureInNavigator(
      context,
      minVisibleExtent: requireVisible ? _minVisibleExtent : 0,
    );
    return rect == null
        ? null
        : ContainerTransformBounds(rect: rect, radius: widget.borderRadius);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
