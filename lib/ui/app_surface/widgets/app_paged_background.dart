import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../controllers/app_background_slot.dart';
import '../models/app_surface_settings.dart';
import '../providers/app_surface_settings_provider.dart';
import '../services/app_background_image_cache.dart';
import '../viewmodels/app_resolved_background.dart';
import 'app_background_layers_view.dart';
import '../viewmodels/app_paged_blend.dart';
import 'app_page_backdrop.dart';

export '../viewmodels/app_paged_blend.dart';
export 'app_page_backdrop.dart';

/// 一组横向翻页的页面（首页各 Tab）共用的背景：画在整组页面下面，按页位置
/// 在相邻两页的区域背景之间插值。
///
/// - [areas] 为各页的区域（页序），[current] 为当前（目标）页；
/// - [interpolate] 为 true 时跟随 [position]（PageView 的小数页码）：滑动到
///   0.3 处就是 70% 前一页 + 30% 后一页的背景，点按切页时 PageView 本身在
///   动画，同一机制覆盖；为 false 时（宽窗口跳页）不看页码，[current] 变化
///   时交叉淡入（`ExpressiveMotion.medium`，减少动画时直接切换）；
/// - 各区域各有一个 [AppBackgroundSlot]，区域自己的设置变化同样交叉淡入；
/// - 只要有任何一页在画背景，整组背景层就一直画，没有背景的页画主题页面
///   底色——插值时下层始终不透明；外壳 Scaffold 此时经 [shellColorOf] 变为
///   透明。所有页都没有背景时什么也不画，只插入 InheritedWidget 与
///   KeyedSubtree，首页与接入前逐像素一致。
///
/// 向子树提供两样东西：本组件之下直接读 [AppPageBackdrop.of] 得到当前页
/// 区域的信息（首页外壳的侧栏、宽窗口切页入场用）；各页用 [AppAreaBackdrop]
/// 包住，读到自己区域的信息（页面底色、实色顶栏底色）。
class AppPagedBackground extends ConsumerStatefulWidget {
  const AppPagedBackground({
    super.key,
    required this.areas,
    required this.current,
    required this.position,
    this.interpolate = true,
    required this.child,
  });

  final List<AppBackgroundArea> areas;
  final int current;
  final ValueListenable<double> position;
  final bool interpolate;
  final Widget child;

  /// 承载整组页面的外壳（如首页 Scaffold）的底色：背景层在画时透明，否则为
  /// 主题页面底色（不在本组件之下时同样是主题页面底色）。
  static Color shellColorOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AppPagedBackdropScope>();
    if (scope != null && scope.painting) return Colors.transparent;
    return ExpressiveSurfaces.pageBackground(Theme.of(context).colorScheme);
  }

  @override
  ConsumerState<AppPagedBackground> createState() => _AppPagedBackgroundState();
}

class _AppPagedBackgroundState extends ConsumerState<AppPagedBackground>
    with TickerProviderStateMixin {
  final Map<AppBackgroundArea, AppBackgroundSlot> _slots =
      <AppBackgroundArea, AppBackgroundSlot>{};
  final Map<AppBackgroundArea, BackdropKey> _backdropKeys =
      <AppBackgroundArea, BackdropKey>{};
  final GlobalKey _childKey = GlobalKey(debugLabel: 'AppPagedBackground child');

  /// 宽窗口切页的交叉淡入：从 [_switchFrom] 区域淡到当前区域。
  late final AnimationController _switch;
  late final CurvedAnimation _switchCurve;
  AppBackgroundArea? _switchFrom;
  bool _built = false;

  @override
  void initState() {
    super.initState();
    _switch = AnimationController(vsync: this, value: 1)
      ..addStatusListener(_handleSwitchStatus);
    _switchCurve = CurvedAnimation(
      parent: _switch,
      curve: ExpressiveMotion.effects,
    );
  }

  AppBackgroundArea get _currentArea =>
      widget.areas[widget.current.clamp(0, widget.areas.length - 1)];

  @override
  void didUpdateWidget(AppPagedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.interpolate || widget.areas.isEmpty || oldWidget.areas.isEmpty) {
      _stopSwitch();
      return;
    }
    final previous =
        oldWidget.areas[oldWidget.current.clamp(0, oldWidget.areas.length - 1)];
    if (previous == _currentArea) return;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (duration == Duration.zero || !widget.areas.contains(previous)) {
      _stopSwitch();
      return;
    }
    _switchFrom = previous;
    _switch
      ..duration = duration
      ..forward(from: 0);
  }

  /// 结束（或不需要）宽窗口切页的交叉淡入，直接显示当前区域。
  void _stopSwitch() {
    if (_switchFrom == null && !_switch.isAnimating) return;
    _switchFrom = null;
    _switch.value = 1;
  }

  void _handleSwitchStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _switchFrom != null) {
      setState(() => _switchFrom = null);
    }
  }

  void _handleSlotChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final slot in _slots.values) {
      slot
        ..removeListener(_handleSlotChanged)
        ..dispose();
    }
    _switchCurve.dispose();
    _switch.dispose();
    super.dispose();
  }

  /// 按当前的区域列表增删 slot（功能管理关掉某个 Tab 时释放它的背景）。
  void _syncSlots() {
    final areas = widget.areas.toSet();
    final removed = _slots.keys.where((area) => !areas.contains(area)).toList();
    for (final area in removed) {
      _slots.remove(area)!
        ..removeListener(_handleSlotChanged)
        ..dispose();
      _backdropKeys.remove(area);
    }
    for (final area in areas) {
      _slots.putIfAbsent(
        area,
        () => AppBackgroundSlot(
          vsync: this,
          cache: ref.read(appBackgroundImageCacheProvider),
        )..addListener(_handleSlotChanged),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final logicalSize = MediaQuery.sizeOf(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final fade = ExpressiveMotion.duration(context, ExpressiveMotion.medium);
    _syncSlots();
    final backdrops = <AppBackgroundArea, AppPageBackdrop>{};
    var painting = false;
    for (final MapEntry(key: area, value: slot) in _slots.entries) {
      slot.update(
        target: AppResolvedBackground.resolve(
          ref.watch(appAreaBackgroundProvider(area)),
          scheme,
        ),
        logicalSize: logicalSize,
        devicePixelRatio: devicePixelRatio,
        fadeDuration: fade,
        animate: _built,
      );
      painting = painting || slot.wantsBackground || slot.isPainting;
      backdrops[area] = slot.backdrop(
        area: area,
        scheme: scheme,
        contentBackdropKey: _backdropKeys.putIfAbsent(area, BackdropKey.new),
      );
    }
    _built = true;

    Widget child = KeyedSubtree(key: _childKey, child: widget.child);
    if (painting && widget.areas.isNotEmpty) {
      child = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(
            child: widget.interpolate
                ? _buildInterpolated()
                : _buildCrossFaded(),
          ),
          child,
        ],
      );
    }
    final current = widget.areas.isEmpty ? null : _currentArea;
    return _AppPagedBackdropScope(
      backdrops: backdrops,
      painting: painting,
      child: AppPageBackdropScope(
        backdrop:
            backdrops[current] ?? AppPageBackdrop.plain(scheme, area: current),
        child: child,
      ),
    );
  }

  Widget _layersOf(AppBackgroundArea area) => AppBackgroundLayersView(
    key: ValueKey<AppBackgroundArea>(area),
    layers: _slots[area]?.layers ?? const <AppBackgroundLayer>[],
    opaque: true,
  );

  /// 跟随页位置：只有这一小块随每帧的页码重建，页面本身不重建。
  Widget _buildInterpolated() {
    final areas = widget.areas;
    return ValueListenableBuilder<double>(
      valueListenable: widget.position,
      builder: (BuildContext context, double page, Widget? _) {
        final blend = AppPagedBlend.at(page, areas.length);
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _layersOf(areas[blend.lower]),
            if (blend.upperOpacity > 0)
              Opacity(
                opacity: blend.upperOpacity,
                child: _layersOf(areas[blend.upper]),
              ),
          ],
        );
      },
    );
  }

  /// 宽窗口：当前区域的背景，切页时从上一区域交叉淡入。
  Widget _buildCrossFaded() {
    final from = _switchFrom;
    if (from == null) return _layersOf(_currentArea);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _layersOf(from),
        FadeTransition(opacity: _switchCurve, child: _layersOf(_currentArea)),
      ],
    );
  }
}

/// 首页某一页（Tab）读自己区域的背景信息：在 [AppPagedBackground] 之下包住
/// 该页，页内 [AppPageBackdrop.of] 得到这个区域的页面底色与实色栏底色。
/// 不在 [AppPagedBackground] 之下时给无背景的默认值。
///
/// 只插入 InheritedWidget，不画任何东西；只在本区域的信息变化时通知页内
/// 的依赖者，别的区域改设置不会让这一页重建。
class AppAreaBackdrop extends StatelessWidget {
  const AppAreaBackdrop({super.key, required this.area, required this.child});

  final AppBackgroundArea area;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AppPagedBackdropScope>();
    return AppPageBackdropScope(
      backdrop:
          scope?.backdrops[area] ??
          AppPageBackdrop.plain(Theme.of(context).colorScheme, area: area),
      child: child,
    );
  }
}

class _AppPagedBackdropScope extends InheritedWidget {
  const _AppPagedBackdropScope({
    required this.backdrops,
    required this.painting,
    required super.child,
  });

  final Map<AppBackgroundArea, AppPageBackdrop> backdrops;
  final bool painting;

  @override
  bool updateShouldNotify(_AppPagedBackdropScope oldWidget) =>
      painting != oldWidget.painting ||
      !mapEquals(backdrops, oldWidget.backdrops);
}
