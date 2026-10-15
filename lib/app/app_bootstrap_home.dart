import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../ui/widgets/expressive_entrance.dart';
import '../ui/widgets/expressive_loading_indicator.dart';
import '../ui/widgets/launch_reveal.dart';
import 'launch_brand_mark.dart';
import 'theme/expressive_motion.dart';

/// 启动阶段：空白底（等待中但尚未到加载页延迟）→ 加载中 → 首页。
enum AppBootstrapPhase { blank, loading, home }

/// 启动引导层：承接原生启动页，就绪后把舞台交给首页。
///
/// 输入：[phase] 启动阶段；[showBrandMark] 原生启动页是否在屏幕中央画了品牌
/// 图形；[holdReveal] 是否暂缓揭幕（应用锁遮罩盖着时）；[homeBuilder] 构建首页，
/// 只在 [AppBootstrapPhase.home] 调用——等待期间不提前装配首页，减少首帧前后
/// 的数据库监听与页面构建，原生启动页移除后尽快接上画面。无副作用。
///
/// 时序：
/// 1. 等待期间只画与原生启动页同色的底，以及同位置、同尺寸的品牌图形，原生
///    闪屏移除时画面不变；超过加载页延迟仍未就绪，图形下方淡入加载指示；
/// 2. 就绪后挂载首页并同时启动两段动画：品牌层在 fast 内后退淡出，首页各区块
///    按 [LaunchRevealSlot] 在 long 内错峰入场。两段动画在挂载首页的这一帧
///    结束后才启动：构建中启动的 Ticker 以本帧时间戳起算，而挂载首页的这一帧
///    最重，它耗时多久，入场开头就会被吃掉多久（品牌图形一帧内跳掉大半）；
/// 3. 应用锁盖着时首页照常挂载，但揭幕暂缓到解锁，与遮罩淡出同时上演；锁若在
///    揭幕开始后才落下（与就绪同帧的竞态），回到起点等解锁；
/// 4. 品牌层退场结束即移出树，加载指示的循环动画随之停止；首页挂载后不再画
///    底色（首页 Scaffold 自带同色不透明底）。
/// 减少动画时两段时长为 0，就绪即直接显示首页。
class AppBootstrapHome extends StatefulWidget {
  const AppBootstrapHome({
    super.key,
    required this.phase,
    required this.showBrandMark,
    required this.holdReveal,
    required this.homeBuilder,
  });

  final AppBootstrapPhase phase;
  final bool showBrandMark;
  final bool holdReveal;
  final WidgetBuilder homeBuilder;

  @override
  State<AppBootstrapHome> createState() => _AppBootstrapHomeState();
}

class _AppBootstrapHomeState extends State<AppBootstrapHome>
    with TickerProviderStateMixin {
  /// 首页编排进度，经 [LaunchRevealScope] 下发。
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: LaunchReveal.duration,
  );

  /// 品牌层退场进度：0 = 完整显示，1 = 已退场（随即移出树）。
  late final AnimationController _brandExit = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.fast,
  )..addStatusListener(_handleBrandExitStatus);
  late final CurvedAnimation _brandExitProgress = CurvedAnimation(
    parent: _brandExit,
    curve: ExpressiveMotion.effects,
  );

  /// 加载指示出现过：品牌层退场期间保留它，与图形一起淡出而不是先一步消失。
  /// 就绪后被应用锁挡住时清除。
  late bool _loaderShown = widget.phase == AppBootstrapPhase.loading;

  /// 已安排在本帧结束后启动揭幕，避免同一帧内重复安排。
  bool _revealScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncReveal();
  }

  @override
  void didUpdateWidget(covariant AppBootstrapHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase == AppBootstrapPhase.loading) {
      _loaderShown = true;
    }
    _syncReveal();
  }

  @override
  void dispose() {
    _brandExitProgress.dispose();
    _brandExit.dispose();
    _reveal.dispose();
    super.dispose();
  }

  /// 按阶段与应用锁决定揭幕：就绪且未被锁挡住时开始，被锁挡住时回到起点。
  void _syncReveal() {
    if (widget.phase != AppBootstrapPhase.home || _reveal.isCompleted) {
      return;
    }
    if (widget.holdReveal) {
      // 设值会停止进行中的动画；品牌层由退场状态派生，回到 0 即重新显示。
      // 已在起点时不再设值，免得每次依赖变化（如主题补间）都通知一遍。
      if (!_reveal.isDismissed) {
        _reveal.value = 0;
      }
      if (!_brandExit.isDismissed) {
        _brandExit.value = 0;
      }
      // 数据已就绪，加载指示不必再转：否则它会在锁屏遮罩下一直循环出帧。
      _loaderShown = false;
      return;
    }
    if (_reveal.isAnimating || _revealScheduled) {
      return;
    }
    final revealDuration = ExpressiveMotion.duration(
      context,
      LaunchReveal.duration,
    );
    if (revealDuration == Duration.zero) {
      // 减少动画：就绪即落定，不等下一帧。
      _reveal.value = 1;
      _brandExit.value = 1;
      return;
    }
    _reveal.duration = revealDuration;
    _brandExit.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.fast,
    );
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      // 等待这一帧期间可能被卸载、被应用锁挡住，或已由其他路径开始。
      if (!mounted ||
          widget.phase != AppBootstrapPhase.home ||
          widget.holdReveal ||
          _reveal.isAnimating ||
          _reveal.isCompleted) {
        return;
      }
      _reveal.forward();
      _brandExit.forward();
    });
  }

  void _handleBrandExitStatus(AnimationStatus status) {
    // 退场完成移出品牌层；被应用锁重置回起点时重新挂上。
    if (status.isCompleted || status.isDismissed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeMounted = widget.phase == AppBootstrapPhase.home;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 与原生启动页同色的底。Stack 以 expand 布局：无子级的 ColoredBox 在
        // 宽松约束下会缩成 0×0、什么都不画，Android 移除原生启动背景后会透出
        // 黑色 Surface（启动黑屏一闪）。
        if (!homeMounted)
          ColoredBox(
            key: const ValueKey<String>('bootstrap_blank'),
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        // 首页与品牌层都带 key：底色移除、品牌层退场时首页不会重新挂载。
        if (homeMounted)
          KeyedSubtree(
            key: const ValueKey<String>('bootstrap_home'),
            child: LaunchRevealScope(
              progress: _reveal,
              child: widget.homeBuilder(context),
            ),
          ),
        if (!_brandExit.isCompleted)
          KeyedSubtree(
            key: const ValueKey<String>('bootstrap_brand'),
            child: IgnorePointer(
              child: _LaunchBrandLayer(
                exit: _brandExitProgress,
                showMark: widget.showBrandMark,
                showLoader:
                    _loaderShown || widget.phase == AppBootstrapPhase.loading,
              ),
            ),
          ),
      ],
    );
  }
}

/// 品牌层：居中的品牌图形 + 其下方的加载指示，退场时整体后退淡出。
class _LaunchBrandLayer extends StatelessWidget {
  const _LaunchBrandLayer({
    required this.exit,
    required this.showMark,
    required this.showLoader,
  });

  // 品牌图形下沿到加载指示的间距与指示尺寸；没有图形时沿用整页加载的尺寸。
  static const double _loaderGap = 32;
  static const double _loaderSizeBelowMark = 40;
  static const double _loaderSizeAlone = 72;

  // 退场终点的缩放：后退约一成，读作“合上封面、翻进内页”。
  static const double _exitScale = 0.9;

  final Animation<double> exit;
  final bool showMark;
  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    final loaderSize = showMark ? _loaderSizeBelowMark : _loaderSizeAlone;
    return AnimatedBuilder(
      animation: exit,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: 1 - exit.value,
          child: Transform.scale(
            scale: 1 - (1 - _exitScale) * exit.value,
            child: child,
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 图形必须恰好位于屏幕正中，与原生闪屏的图标重合。
          if (showMark) const Center(child: LaunchBrandMark()),
          if (showLoader)
            Center(
              child: Transform.translate(
                offset: showMark
                    ? const Offset(
                        0,
                        LaunchBrandMark.height / 2 +
                            _loaderGap +
                            _loaderSizeBelowMark / 2,
                      )
                    : Offset.zero,
                child: ExpressiveEntrance(
                  child: ExpressiveLoadingIndicator(
                    key: const ValueKey<String>('bootstrap_loader'),
                    size: loaderSize,
                    semanticLabel: context.l10n.autoT0001,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
