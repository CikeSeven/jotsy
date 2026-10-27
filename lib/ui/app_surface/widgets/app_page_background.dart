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
  const AppPageBackground({super.key, required this.area, required this.child});

  final AppBackgroundArea area;
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
        ref.watch(appAreaBackgroundProvider(widget.area)),
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
      child = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(child: AppBackgroundLayersView(layers: _slot.layers)),
          child,
        ],
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
