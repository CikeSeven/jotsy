import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/expressive_motion.dart';
import '../controllers/app_background_slot.dart';
import '../models/app_surface_settings.dart';
import '../providers/app_surface_settings_provider.dart';
import '../services/app_background_image_cache.dart';
import '../viewmodels/app_resolved_background.dart';
import 'app_background_layers_view.dart';
import 'app_page_backdrop.dart';

export 'app_page_backdrop.dart';

/// 页面背景：在页面（通常是 Scaffold）下面画 [area] 区域的背景，并经
/// [AppPageBackdrop] 告诉子树该用什么底色。
///
/// 用法：包在路由页面的最外层，页面 Scaffold 的 `backgroundColor` 改为
/// `AppPageBackdrop.pageColorOf(context)`（在本组件之下的 context 读）。
///
/// - 背景由页面自己画，随路由一起转场；铺满本组件（即路由）的大小，在
///   Scaffold 外面，键盘弹出时不缩放、不移动；
/// - 设置变化（含明暗切换）时交叉淡入，规则见 [AppBackgroundSlot]；
/// - 默认设置（无背景）下只插入一个 InheritedWidget 与一个 KeyedSubtree，
///   不画任何东西，页面与接入前逐像素一致。设置要求画背景时才在页面下面
///   垫一层 Stack；页面挂在 GlobalKey 下，两种结构切换时整棵搬过去、不重建
///   （滚动位置、输入焦点都保留）。结构只随“设置要不要背景”切换，不随
///   解码完成切换，打开页面时图片解码回来不会搬动正在输入的编辑器。
class AppPageBackground extends ConsumerStatefulWidget {
  const AppPageBackground({super.key, required this.area, required this.child})
    : background = null;

  /// 设置页预览用：画给定的 [background]（如编辑中的草稿），不读已保存的
  /// 设置。图片解码、缓存、遮罩与交叉淡入与正式页面同一套管线；解码尺寸
  /// 取本组件之上 MediaQuery 的尺寸，预览把它换成所模拟手机的尺寸，模糊
  /// 半径与真实页面一致（尺寸相同时还能直接命中真实页面的解码缓存）。
  const AppPageBackground.preview({
    super.key,
    required this.area,
    required AppBackground this.background,
    required this.child,
  });

  final AppBackgroundArea area;

  /// 指定要画的背景；为 null 时读 [area] 已保存的设置。
  final AppBackground? background;
  final Widget child;

  @override
  ConsumerState<AppPageBackground> createState() => _AppPageBackgroundState();
}

class _AppPageBackgroundState extends ConsumerState<AppPageBackground>
    with TickerProviderStateMixin {
  late final AppBackgroundSlot _slot = AppBackgroundSlot(
    vsync: this,
    cache: ref.read(appBackgroundImageCacheProvider),
  )..addListener(_handleSlotChanged);

  /// 留给后续内容玻璃共用背景读取（见 [AppPageBackdrop.contentBackdropKey]）。
  final BackdropKey _contentBackdropKey = BackdropKey();
  final GlobalKey _childKey = GlobalKey(debugLabel: 'AppPageBackground child');
  bool _built = false;

  void _handleSlotChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _slot
      ..removeListener(_handleSlotChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 在 build 中同步推进背景状态（只改内部状态、不通知）：首帧就能拿到
    // 已缓存的背景，页面随路由滑入时背景已经在那里。
    _slot.update(
      target: AppResolvedBackground.resolve(
        widget.background ?? ref.watch(appAreaBackgroundProvider(widget.area)),
        scheme,
      ),
      logicalSize: MediaQuery.sizeOf(context),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      fadeDuration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      animate: _built,
    );
    _built = true;
    Widget child = KeyedSubtree(key: _childKey, child: widget.child);
    if (_slot.wantsBackground || _slot.isPainting) {
      final layers = _slot.layers;
      // 图层只在画背景的这一支交给子树（AppPageBackgroundCopy 用），默认
      // 设置下的结构不多出节点。
      child = _AppPageBackgroundLayersScope(
        layers: layers,
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            Positioned.fill(child: AppBackgroundLayersView(layers: layers)),
            child,
          ],
        ),
      );
    }
    return AppPageBackdropScope(
      backdrop: _slot.backdrop(
        area: widget.area,
        scheme: scheme,
        contentBackdropKey: _contentBackdropKey,
      ),
      child: child,
    );
  }
}

/// 在页面内容里再画一份所在 [AppPageBackground] 的背景：同一组图层（同一张
/// 已解码的图、同样的 cover 对齐与遮罩、交叉淡入同步），铺满本组件。
///
/// 用途：页面里某块“与页面同尺寸”的内容需要自带不透明的底，又要看起来
/// 与页面背景无缝——如预览页翻页器在层叠 / 淡入转场下，每篇各自垫一份，
/// 两篇重叠时不会互相透出。尺寸与页面背景相同、位置重合时与下面的页面背景
/// 逐像素一致；随内容平移 / 缩放时背景跟着动（这正是它与页面背景的区别）。
///
/// 没有祖先背景、或背景什么也没画时不画任何东西（[SizedBox.expand]）；画了
/// 背景时最下面垫一层页面底色，保证不透明（见 `AppBackgroundLayersView.opaque`）。
class AppPageBackgroundCopy extends StatelessWidget {
  const AppPageBackgroundCopy({super.key});

  @override
  Widget build(BuildContext context) {
    final layers = context
        .dependOnInheritedWidgetOfExactType<_AppPageBackgroundLayersScope>()
        ?.layers;
    if (layers == null || layers.isEmpty) {
      return const SizedBox.expand();
    }
    return AppBackgroundLayersView(layers: layers, opaque: true);
  }
}

/// 把背景图层交给 [AppPageBackgroundCopy]。`layers` 每次构建都是新的只读
/// 列表，按元素比较：图层不变时不通知依赖者。
class _AppPageBackgroundLayersScope extends InheritedWidget {
  const _AppPageBackgroundLayersScope({
    required this.layers,
    required super.child,
  });

  final List<AppBackgroundLayer> layers;

  @override
  bool updateShouldNotify(_AppPageBackgroundLayersScope oldWidget) =>
      !listEquals(layers, oldWidget.layers);
}
