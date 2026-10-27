import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../models/app_surface_settings.dart';
import '../services/app_background_image_cache.dart';
import '../viewmodels/app_resolved_background.dart';
import '../widgets/app_page_backdrop.dart';

/// 一层背景要画的内容：目标背景 + （图片时）解码好的句柄。
class AppBackgroundVisual {
  AppBackgroundVisual._(this.background, this.image);

  /// 画主题页面底色的一层（“无背景”在交叉淡入里也要不透明地画出来）。
  static AppBackgroundVisual none() =>
      AppBackgroundVisual._(AppResolvedBackground.none, null);

  final AppResolvedBackground background;

  /// 图片背景的句柄（归所在的层持有）；其余种类为 null。
  final AppBackgroundImage? image;

  bool get isNone => background.isNone;
}

/// 背景的一层：内容 + 透明度。最底下的一层始终不透明，上面的层在淡入。
class AppBackgroundLayer {
  AppBackgroundLayer._(this.visual, this._controller, this.opacity);

  /// 不需要动画、直接完全显示的一层。
  AppBackgroundLayer._settled(AppBackgroundVisual visual)
    : this._(visual, null, kAlwaysCompleteAnimation);

  /// 内容；同一张图只改焦点 / 遮罩 / 清晰度时原地替换，不另起一层。
  AppBackgroundVisual visual;
  final AnimationController? _controller;
  final Animation<double> opacity;

  /// 渲染层的 key：层增减时各层按身份对应，不按位置复用。
  final Key key = UniqueKey();

  void _dispose() {
    visual.image?.dispose();
    if (opacity is CurvedAnimation) {
      (opacity as CurvedAnimation).dispose();
    }
    _controller?.dispose();
  }
}

/// 一块背景（一个页面或首页的一个区域）的显示状态机。
///
/// 输入：每次 build 经 [update] 给出的目标背景、显示尺寸与淡入时长；输出：
/// 自下而上的 [layers] 与据此推出的 [backdrop]；副作用：向图片缓存请求解码、
/// 持有并释放图片句柄、驱动淡入动画（ticker 来自宿主 State）。
///
/// 状态与切换：
/// - 静止：没有层（不画，页面自己的底色露出来）或恰好一层完全显示；
/// - 目标变化：纯色 / 无背景立即开始交叉淡入；图片先查缓存，命中立即淡入，
///   未命中先保持当前层，解码完成且仍是最新目标时再淡入（期间又换了目标则
///   丢弃结果）。解码失败按无背景处理；
/// - 淡入：新层压在最上面由透明到不透明，下面的层保持原样不透明，新层到位
///   后移除它下面的全部层。原本没有层时先垫一层“无背景”（主题页面底色）：
///   页面一旦开始显示背景就改为透明底，淡入期间下面必须有不透明的东西；
///   淡入到“无背景”结束后，只剩的那层与页面自己的底色相同，直接移除，
///   页面恢复不画背景；
/// - 同一张图只换焦点、遮罩、尺寸档：原地替换最上层，不交叉淡入——拖动
///   遮罩滑杆、桌面拖窗口跨档时不会每一步都闪一次；
/// - 减少动画（淡入时长为 0）或首帧（[update] 的 `animate` 为 false）：
///   直接换成目标。
///
/// [update] 在宿主的 build 中同步调用，只改内部状态、不通知；异步解码完成
/// 与淡入结束时才 [notifyListeners]，宿主据此 setState。
class AppBackgroundSlot extends ChangeNotifier {
  AppBackgroundSlot({required this.vsync, required this.cache});

  /// 淡入动画的 ticker 来源（宿主 State）。
  final TickerProvider vsync;

  /// 解码与复用图片的缓存。
  final AppBackgroundImageCache cache;
  final List<AppBackgroundLayer> _layers = <AppBackgroundLayer>[];

  AppResolvedBackground _target = AppResolvedBackground.none;
  AppBackgroundImageKey? _targetKey;
  Duration _fadeDuration = ExpressiveMotion.medium;

  /// 目标的代次：异步解码回来时据此判断是否已过时。
  int _generation = 0;
  bool _disposed = false;

  /// 自下而上要画的层；为空时不画任何东西。
  List<AppBackgroundLayer> get layers =>
      List<AppBackgroundLayer>.unmodifiable(_layers);

  /// 此刻是否在画背景（含淡入淡出过程）。
  bool get isPainting => _layers.isNotEmpty;

  /// 设置是否要求画背景（图片可能还在解码或读取失败）。宿主据此决定是否
  /// 挂上背景所需的结构，避免解码完成那一刻改变页面的挂载位置。
  bool get wantsBackground => !_target.isNone;

  AppResolvedBackground get target => _target;

  /// 最上面（正在显示或淡入）的内容。
  AppBackgroundVisual? get front =>
      _layers.isEmpty ? null : _layers.last.visual;

  /// 同步更新目标背景。
  ///
  /// [logicalSize] / [devicePixelRatio] 决定图片的解码尺寸档；
  /// [fadeDuration] 为交叉淡入时长（已按减少动画解析，0 为直接切换）；
  /// [animate] 为 false 时（宿主首次构建）缓存命中的图片与纯色直接显示，
  /// 页面随路由滑入时背景已经在那里。
  void update({
    required AppResolvedBackground target,
    required Size logicalSize,
    required double devicePixelRatio,
    required Duration fadeDuration,
    bool animate = true,
  }) {
    _fadeDuration = fadeDuration;
    final image = target.image;
    final key = image == null
        ? null
        : AppBackgroundImageKey.forDisplay(
            fileName: image,
            blur: target.blur,
            logicalSize: logicalSize,
            devicePixelRatio: devicePixelRatio,
          );
    if (target == _target && key == _targetKey) return;
    _target = target;
    _targetKey = key;
    final generation = ++_generation;
    if (key == null) {
      _show(AppBackgroundVisual._(target, null), animate: animate);
      return;
    }
    final frontKey = front?.image?.key;
    final sameImage = frontKey != null && frontKey.sameImageAs(key);
    if (sameImage && frontKey == key) {
      _replaceFront(target);
      return;
    }
    final hit = cache.peek(key);
    if (hit != null) {
      if (sameImage) {
        _replaceFront(target, image: hit);
      } else {
        _show(AppBackgroundVisual._(target, hit), animate: animate);
      }
      return;
    }
    // 新尺寸档还没解码：先用旧档，焦点与遮罩立即跟上。
    if (sameImage) _replaceFront(target);
    cache.load(key).then((loaded) => _onLoaded(generation, loaded));
  }

  void _onLoaded(int generation, AppBackgroundImage? loaded) {
    if (_disposed || generation != _generation) {
      loaded?.dispose();
      return;
    }
    if (loaded == null) {
      _show(AppBackgroundVisual.none(), animate: true);
    } else {
      final frontKey = front?.image?.key;
      if (frontKey != null && frontKey.sameImageAs(loaded.key)) {
        _replaceFront(_target, image: loaded);
      } else {
        _show(AppBackgroundVisual._(_target, loaded), animate: true);
      }
    }
    notifyListeners();
  }

  /// 原地替换最上层的内容（同一张图）；给出 [image] 时换上新句柄、释放旧的。
  void _replaceFront(
    AppResolvedBackground target, {
    AppBackgroundImage? image,
  }) {
    final layer = _layers.last;
    final previous = layer.visual.image;
    if (image != null) previous?.dispose();
    layer.visual = AppBackgroundVisual._(target, image ?? previous);
  }

  void _show(AppBackgroundVisual visual, {required bool animate}) {
    if (!animate || _fadeDuration == Duration.zero) {
      _clear();
      if (!visual.isNone) _layers.add(AppBackgroundLayer._settled(visual));
      return;
    }
    if (_layers.isEmpty) {
      if (visual.isNone) return;
      _layers.add(AppBackgroundLayer._settled(AppBackgroundVisual.none()));
    }
    final controller = AnimationController(
      vsync: vsync,
      duration: _fadeDuration,
    );
    final layer = AppBackgroundLayer._(
      visual,
      controller,
      CurvedAnimation(parent: controller, curve: ExpressiveMotion.effects),
    );
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _settle(layer);
    });
    _layers.add(layer);
    controller.forward();
  }

  /// [layer] 淡入完成：移除它下面的层；最后只剩“无背景”时整块不画。
  void _settle(AppBackgroundLayer layer) {
    if (_disposed) return;
    final index = _layers.indexOf(layer);
    if (index < 0) return;
    for (final below in _layers.sublist(0, index)) {
      below._dispose();
    }
    _layers.removeRange(0, index);
    if (_layers.length == 1 && _layers.single.visual.isNone) {
      _clear();
    }
    notifyListeners();
  }

  void _clear() {
    for (final layer in _layers) {
      layer._dispose();
    }
    _layers.clear();
  }

  /// 由当前层推出交给子树的信息（口径见 [AppPageBackdrop]）。
  AppPageBackdrop backdrop({
    required AppBackgroundArea area,
    required ColorScheme scheme,
    BackdropKey? contentBackdropKey,
  }) {
    final visual = front;
    if (visual == null) {
      return AppPageBackdrop.plain(
        scheme,
        area: area,
        contentBackdropKey: contentBackdropKey,
      );
    }
    final background = visual.background;
    final color = background.color;
    final scrim = background.scrimColor;
    final Color estimated;
    if (background.isImage && scrim != null) {
      final average = visual.image?.averageColor;
      final under = average == null
          ? scheme.surface
          : Color.alphaBlend(average, scheme.surface);
      estimated = Color.alphaBlend(scrim, under);
    } else {
      estimated = color ?? scheme.surface;
    }
    return AppPageBackdrop(
      area: area,
      hasBackground: true,
      hasImage: background.isImage,
      pageColor: Colors.transparent,
      solidBarColor: color ?? scheme.surface,
      estimatedColor: estimated,
      contentBackdropKey: contentBackdropKey,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _clear();
    super.dispose();
  }
}
